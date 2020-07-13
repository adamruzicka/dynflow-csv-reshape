= Dynflow CSV reshape

A tiny utility for reshaping postgres CSV dumps of dynflow tables into a YAML,
structuring information similarly to how the dynflow console does it.

## Input data:

### dynflow_execution_plans.csv
```
uuid,data,state,result,started_at,ended_at,real_time,execution_time,label,class,run_flow,finalize_flow,execution_history,root_plan_step_id,step_ids
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,,stopped,success,2020-07-02 06:31:55.522,2020-07-02 06:32:00.818,5.296545961,5.279909049,Actions::Katello::Host::GenerateApplicability,Dynflow::ExecutionPlan,"{""class"":""Dynflow::Flows::Atom"",""step_id"":3}","{""class"":""Dynflow::Flows::Sequence"",""flows"":[{""class"":""Dynflow::Flows::Atom"",""step_id"":4}]}","[{""time"":1593671515,""name"":""start execution"",""world_id"":""1911b6d5-a103-41d6-8871-4f3331ea3823""},{""time"":1593671520,""name"":""finish execution"",""world_id"":""1911b6d5-a103-41d6-8871-4f3331ea3823""}]",1,"[1,2,3,4]"
```

### dynflow_actions.csv
```
execution_plan_uuid,id,data,caller_execution_plan_id,caller_action_id,class,input,output,plan_step_id,run_step_id,finalize_step_id
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,2,,,1,Actions::Pulp::Consumer::GenerateApplicability,"{""uuids"":[""e49bc81b-6117-493a-9880-470c4225ef45""],""remote_user"":""admin"",""remote_cp_user"":""admin"",""current_request_id"":null,""current_timezone"":""UTC"",""current_user_id"":1,""current_organization_id"":null,""current_location_id"":null}","{""pulp_tasks"":[{""exception"":null,""task_type"":""pulp.server.managers.consumer.applicability.regenerate_applicability_for_consumers"",""_href"":""/pulp/api/v2/tasks/4bbb81a8-20a0-49f7-97bb-b41427ccbf4d/"",""task_id"":""4bbb81a8-20a0-49f7-97bb-b41427ccbf4d"",""tags"":[""pulp:action:consumer_content_applicability_regeneration""],""finish_time"":""2020-07-02T06:31:55Z"",""_ns"":""task_status"",""start_time"":""2020-07-02T06:31:55Z"",""traceback"":null,""spawned_tasks"":[],""progress_report"":{},""queue"":""reserved_resource_worker-4@myhost.somewhere.com"",""state"":""finished"",""worker_name"":""reserved_resource_worker-4@myhost.somewhere.com"",""result"":null,""error"":null,""_id"":{""$oid"":""5efd7f5b54c2485917ac7524""},""id"":""5efd7f5b54c2485917ac7524""}]}",2,3
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,1,,,,Actions::Katello::Host::GenerateApplicability,"{""services_checked"":[""pulp"",""pulp_auth""],""host_ids"":[1293],""use_queue"":true,""current_request_id"":null,""current_timezone"":""UTC"",""current_user_id"":1,""current_organization_id"":null,""current_location_id"":null}",{},1,,4
```

### dynflow_steps.csv
```
execution_plan_uuid,id,action_id,data,state,started_at,ended_at,real_time,execution_time,progress_done,progress_weight,class,error,action_class,children,queue
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,1,1,,success,2020-07-02 06:31:55.545332,2020-07-02 06:31:55.652983,0.107651661,0.107651661,1,0,Dynflow::ExecutionPlan::Steps::PlanStep,,Actions::Katello::Host::GenerateApplicability,[2]
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,2,2,,success,2020-07-02 06:31:55.551141,2020-07-02 06:31:55.648026,0.096884457,0.096884457,1,0,Dynflow::ExecutionPlan::Steps::PlanStep,,Actions::Pulp::Consumer::GenerateApplicability,[]
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,3,2,,success,2020-07-02 06:31:55.725549,2020-07-02 06:32:00.794602,5.06905275,5.06905275,1,1,Dynflow::ExecutionPlan::Steps::RunStep,,Actions::Pulp::Consumer::GenerateApplicability,,hosts_queue
a833bd13-da47-4a25-b7f1-ee9af2bb83fa,4,1,,success,2020-07-02 06:32:00.804288,2020-07-02 06:32:00.810608,0.006320181,0.006320181,1,1,Dynflow::ExecutionPlan::Steps::FinalizeStep,,Actions::Katello::Host::GenerateApplicability,,hosts_queue
```

## Running
The primary mode of operation is reformatting input CSV files into a different
structure. This *REQUIRES* the files to be valid CSVs with headers.

```
ruby dynflow-csv-reshape.rb \
    --execution-plans execution_plans.csv \
    --actions actions.csv \
    --steps steps.csv \
    --output export.yaml
```

Running this command on the example data above yield the following result:
```
---
- uuid: a833bd13-da47-4a25-b7f1-ee9af2bb83fa
  label: Actions::Katello::Host::GenerateApplicability
  state: stopped
  result: success
  started_at: '2020-07-02 06:31:55.522'
  ended_at: '2020-07-02 06:32:00.818'
  real_time: '5.296545961'
  execution_time: '5.279909049'
  class: Dynflow::ExecutionPlan
  execution_history:
  - time: 1593671515
    name: start execution
    world_id: 1911b6d5-a103-41d6-8871-4f3331ea3823
  - time: 1593671520
    name: finish execution
    world_id: 1911b6d5-a103-41d6-8871-4f3331ea3823
  plan_phase:
    id: 1
    label: Actions::Katello::Host::GenerateApplicability
    input:
      services_checked:
      - pulp
      - pulp_auth
      host_ids:
      - 1293
      use_queue: true
      current_request_id: 
      current_timezone: UTC
      current_user_id: 1
      current_organization_id: 
      current_location_id: 
    state: success
    queue: 
    started_at: '2020-07-02 06:31:55.545332'
    ended_at: '2020-07-02 06:31:55.652983'
    real_time: '0.107651661'
    execution_time: '0.107651661'
    children:
    - id: 2
      label: Actions::Pulp::Consumer::GenerateApplicability
      input:
        uuids:
        - e49bc81b-6117-493a-9880-470c4225ef45
        remote_user: admin
        remote_cp_user: admin
        current_request_id: 
        current_timezone: UTC
        current_user_id: 1
        current_organization_id: 
        current_location_id: 
      state: success
      queue: 
      started_at: '2020-07-02 06:31:55.551141'
      ended_at: '2020-07-02 06:31:55.648026'
      real_time: '0.096884457'
      execution_time: '0.096884457'
      children: []
  run_phase:
    type: concurrence
    children:
    - id: 3
      label: Actions::Pulp::Consumer::GenerateApplicability
      input:
        uuids:
        - e49bc81b-6117-493a-9880-470c4225ef45
        remote_user: admin
        remote_cp_user: admin
        current_request_id: 
        current_timezone: UTC
        current_user_id: 1
        current_organization_id: 
        current_location_id: 
      output:
        pulp_tasks:
        - exception: 
          task_type: pulp.server.managers.consumer.applicability.regenerate_applicability_for_consumers
          _href: "/pulp/api/v2/tasks/4bbb81a8-20a0-49f7-97bb-b41427ccbf4d/"
          task_id: 4bbb81a8-20a0-49f7-97bb-b41427ccbf4d
          tags:
          - pulp:action:consumer_content_applicability_regeneration
          finish_time: '2020-07-02T06:31:55Z'
          _ns: task_status
          start_time: '2020-07-02T06:31:55Z'
          traceback: 
          spawned_tasks: []
          progress_report: {}
          queue: reserved_resource_worker-4@myhost.somewhere.com
          state: finished
          worker_name: reserved_resource_worker-4@myhost.somewhere.com
          result: 
          error: 
          _id:
            "$oid": 5efd7f5b54c2485917ac7524
          id: 5efd7f5b54c2485917ac7524
      state: success
      queue: hosts_queue
      started_at: '2020-07-02 06:31:55.725549'
      ended_at: '2020-07-02 06:32:00.794602'
      real_time: '5.06905275'
      execution_time: '5.06905275'
  finalize_phase:
    type: sequence
    children:
    - id: 4
      label: Actions::Katello::Host::GenerateApplicability
      input:
        services_checked:
        - pulp
        - pulp_auth
        host_ids:
        - 1293
        use_queue: true
        current_request_id: 
        current_timezone: UTC
        current_user_id: 1
        current_organization_id: 
        current_location_id: 
      output: {}
      state: success
      queue: hosts_queue
      started_at: '2020-07-02 06:32:00.804288'
      ended_at: '2020-07-02 06:32:00.810608'
      real_time: '0.006320181'
      execution_time: '0.006320181'
```

### Preprocessing CSV files
There is an issues with the current way how we create the CSV files. When we
create them, we don't escape them properly. This tool can try to fix the
malformed file, but the approach to it is rather simplistic so ymmv. To use it,
use the `--preprocess FILE --output FIXED_FILE` flags. It will try to escape the
contents of `FILE` and save it as `FIXED_FILE`.
