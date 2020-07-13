require 'csv'
require 'json'
require 'yaml'
require 'optparse'

def read_field(line)
  if ['{', '['].include? line[0]
    stack = [line[0]]
    end_i = 1
    loop do
      c = line[end_i]
      if ['{', '['].include? c
        stack << c
      elsif (c == '}' && stack.last == '{') || (c == ']' && stack.last == '[')
        stack.pop
      end
      break if stack.empty?
      end_i += 1
    end
    [line[0..end_i], line[end_i + 2..]]
  else
    line.split(',', 2)
  end
end

def preprocess(filename, out)
  csv = CSV.new out
  File.readlines(filename).each do |line|
    line = line.chomp
    cells = []
    while !line.nil? && !line.empty?
      cell, line = read_field line
      cell = nil if cell == ''
      cells << cell
    end
    csv << cells
  end
  csv.close
end

def load_data(execution_plans_file, actions_file, steps_file)
  execution_plans = CSV.read(execution_plans_file, headers: true)
  execution_plans = Hash[execution_plans.map { |plan| [plan['uuid'], plan] }]

  actions = {}
  CSV.read(actions_file, headers: true).each do |row|
    ep_uuid = row['execution_plan_uuid']
    actions[ep_uuid] ||= {}
    actions[ep_uuid][row['id'].to_i] = row
  end

  steps = {}
  CSV.read(steps_file, headers: true).each do |row|
    ep_uuid = row['execution_plan_uuid']
    steps[ep_uuid] ||= {}
    steps[ep_uuid][row['id'].to_i] = row
  end

  [execution_plans, actions, steps]
end

def parse_json(parent, key, default)
  if parent.key? key
    JSON.parse parent[key] if parent[key]
  else
    default
  end
end

def export_step(id, actions, steps, phase)
  step_row = steps[id]

  base = { 'id' => id }

  action = if step_row
             actions[step_row['action_id'].to_i]
           else
             actions.values.find { |action| action["#{phase}_step_id"].to_i == id }
           end

  if action
    base['label']  = action['label']
    base['input']  = parse_json(action, 'input', 'UNAVAILALBE')
    base['output'] = parse_json(action, 'output', 'UNAVAILABLE') if phase != :plan
  end

  if step_row
    base = base.merge(step_row.to_h.slice(*%w(state queue started_at ended_at real_time execution_time)))
    base['label'] ||= step_row['action_class']

    base['error'] = JSON.parse(step_row['error']) if step_row['error']

    if phase == :plan
      child_steps = JSON.parse(step_row['children'])
      base['children'] = child_steps.map { |step_id| export_step step_id, actions, steps, :plan }
    end
  end

  base
end

def export_flow(flow_hash, execution_plan_id, actions, steps)
  case flow_hash['class']
    when 'Dynflow::Flows::Atom'
      export_step(flow_hash['step_id'], actions, steps, :run)
    when 'Dynflow::Flows::Sequence'
      { 'type' => 'sequence',
        'children' => flow_hash['flows'].map { |sub_flow| export_flow(sub_flow, execution_plan_id, actions, steps) } }
    when 'Dynflow::Flows::Concurrence'
      { 'type' => 'concurrence',
        'children' => flow_hash['flows'].map { |sub_flow| export_flow(sub_flow, execution_plan_id, actions, steps) } }
  end
end

def export_execution_plan(execution_plan_row, actions, steps)
  base = execution_plan_row.to_h.slice('uuid', 'label', 'state', 'result', 'started_at', 'ended_at', 'real_time', 'execution_time', 'class', 'execution_history')
  base['execution_history'] = JSON.parse(base['execution_history'])

  plan_steps = steps[execution_plan_row['uuid']]
  plan_actions = actions[execution_plan_row['uuid']] || {}

  if plan_steps
    plan_step = plan_steps[execution_plan_row['root_plan_step_id'].to_i]
    base['plan_phase'] = if plan_step
                           export_step(execution_plan_row['root_plan_step_id'].to_i, plan_actions, plan_steps, :plan)
                         else
                           'UNAVAILABLE'
                         end

    %w(run finalize).each do |flow_kind|
      flow = JSON.parse(execution_plan_row["#{flow_kind}_flow"])
      flow = {'class' => 'Dynflow::Flows::Concurrence', 'flows' => [flow]} if flow['class'] == 'Dynflow::Flows::Atom'
      base["#{flow_kind}_phase"] = export_flow(flow, execution_plan_row['uuid'], plan_actions, plan_steps)
    end
  else
    %w(plan run finalize).each do |phase|
      base["#{phase}_phase"] = 'UNAVAILABLE'
    end
  end

  base
end

Options = Struct.new(:execution_plans, :actions, :steps, :output, :preprocess)
options = Options.new(nil, nil, nil, STDOUT)
OptionParser.new do |parser|
  parser.on("-eEXECUTION_PLANS", "--execution-plans=EXECUTION_PLANS", "File containing CSV export of execution plans") do |execution_plans|
    options.execution_plans = execution_plans
  end
  parser.on("-aACTIONS", "--actions=ACTIONS", "File containing CSV export of actions") do |actions|
    options.actions = actions
  end
  parser.on("-sSTEPS", "--steps=STEPS", "File containing CSV export of steps") do |steps|
    options.steps = steps
  end

  parser.on("-O", "--output [OUTPUT]", "Write result into OUTPUT file") do |output|
    options.output = File.open(output, 'w')
  end

  parser.on("-pCSV", "--preprocess=CSV", "Try to fix wrong escaping in a CSV file") do |preprocess|
    options.preprocess = preprocess
  end
end.parse!

if options.preprocess
  preprocess(options.preprocess, options.output)
else
  if options.to_h.slice(:execution_plans, :actions, :steps).values.any?(&:nil?)
    raise "execution plans, actions and steps need to be provided"
  else
    execution_plans, actions, steps = load_data(*options.to_h.slice(:execution_plans, :actions, :steps).values)

    plans = execution_plans.values.map do |execution_plan_row|
      export_execution_plan(execution_plan_row, actions, steps)
    end

    options.output.puts(YAML.dump(plans))
  end
end
