def kv (k):
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
  unique_tags[] as $tag | all | map([.PrivateIpAddress, "\($tag)-\(.[$tag]//"")" ]);

def insert_hosts(hosts):
  reduce (hosts | to_entries)[] as $ele ({}; .[$ele.key] = { hosts: $ele.value });

def into_ansible:
  # All instances in a flat list
  [ .Reservations[].Instances[] ] |

  # Only running instances
  map(select(.State.Name == "running")) | 

  # Tags list into a map
  map(.Tags |= 
    reduce (.//[])[] as $t 
      ({}; .[$t.Key | gsub("[^\\w]"; "_")] = $t.Value)) |

  # Remap instances by instance id, sorted keys in value
  map({ key: .PrivateIpAddress, 
        value: (to_entries | sort_by(.key) | flat | flat | flat | from_entries) }) | from_entries |

      # Save map
      . as $all | $all |

      # Start dynamic inventory with the metadata
      { _meta: { hostvars: . } } +

      # Group all the hosts
      { all: { hosts: keys } } +

      # Group by having a tag name
      insert_hosts(reduce unique_tags[] as $tag
        ({}; .[$tag] |= . + [$all | map(select(has($tag)))[].PrivateIpAddress])) +

      # Group by having a tag value
      insert_hosts(reduce instance_tag_value($all)[] as $itv
        ({}; .[$itv[1]] |= . + [$itv[0]])) +

      # Return the dynamic inventory
      {};

into_ansible
