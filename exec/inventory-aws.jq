def kv(k):
  if type == "array" then
    . as $in | keys[] | 
    if . == 0 then
      $in[.] | kv(k)
    else
      "\(k)_\(.)" as $kk | $in[.] | kv($kk)
    end
  elif type == "object" then
    to_entries | map(["\(k)_\(if k == "Tags" then .key | ascii_downcase else .key end)", .value]) | .[]
  else
    [ k, . ]
  end;

def flat:
  map("\(.key)" as $k | .value | kv($k)) |
  map(select(length > 0)) |
  map({key: .[0], value: .[1]});

def unique_tags:
  [ .[] | keys | map(select(startswith("Tags_")))[] ] | unique;

def instance_tag_value (all):
  unique_tags[] as $tag | all | map([.DeployName, "\($tag)-\(.[$tag]//"" | gsub("\\s+"; "_"))" ]);

def insert_hosts(hosts):
  reduce (hosts | to_entries)[] as $ele ({}; .[$ele.key] = { hosts: ($ele.value | sort) });

def opt_dash(n):
  n | if . then "\(.)-" else empty end;

def fqhostname:
  "\(opt_dash(.Tags_env)//"unknown")\(opt_dash(.Tags_app)//opt_dash(.Tags_node)//"")\(opt_dash(.Tags_service)//"")\(.InstanceId)";

def flatten_hostvars:
  to_entries | sort_by(.key) | flat | flat | flat | from_entries;

def annotate_ssh:
  {
    ansible_host: .PrivateIpAddress,
    ansible_user: (.Tags_ssh_user//"ubuntu"),
    ansible_port: (.Tags_ssh_port//"22")
  };

def annotate_deploy:
  {
    DeployName: "\(fqhostname)-\(.PrivateIpAddress)",
    hostname: "\(fqhostname)",
    env: .Tags_env,
    app: .Tags_app,
    service: .Tags_service
  };

def into_ansible:
  # Assumes input has slurped Reservations[].Instances[] into a single list

  # Only running instances
  map(select(.State.Name == "running")) | 

  # No windows instances
  map(select(.Platform != "windows")) | 

  # Tags list into a map
  map(.Tags |= 
    reduce (.//[])[] as $t 
      ({}; .[$t.Key | gsub("[^\\w]"; "_")] = $t.Value)) |

  # No EMR instances
  map(select(.Tags | has("aws_elasticmapreduce_instance_group_role") | not)) | 

  # Remap instances by private ip, sorted keys in value
  map(flatten_hostvars | { key: "\(fqhostname)-\(.PrivateIpAddress)",
        value: (. + annotate_ssh + annotate_deploy)
      }) | from_entries |

  # Save map
  . as $all |

    # Start dynamic inventory with the metadata
    { _meta: { hostvars: . } } +

    # Group by InstanceId
    reduce (to_entries)[] as $ele ({}; .[$ele.value.InstanceId] = { hosts: [$ele.key]}) +

    # Group by PrivateIpAddress
    reduce (to_entries)[] as $ele ({}; .[$ele.value.PrivateIpAddress] = { hosts: [$ele.key]}) +

    # Group by hostname
    reduce (to_entries)[] as $ele ({}; .[$ele.value.hostname] = { hosts: [$ele.key]}) +

    # Group by having a tag name
    insert_hosts(reduce unique_tags[] as $tag
      ({}; .[$tag] |= . + [$all | map(select(has($tag)))[].DeployName])) +

    # Group by having a tag value
    insert_hosts(reduce instance_tag_value($all)[] as $itv
      ({}; .[$itv[1]] |= . + [$itv[0]])) +

    # Return the dynamic inventory
    {};

into_ansible
