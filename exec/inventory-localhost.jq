def into_ansible:
  # Reduces nodes into a map indexed by nodename.nih
  reduce .[] as $ele ({}; .["\($ele.Host)"] = { ansible_user: $ele.User, ansible_host: $ele.HostName } ) |

  . as $all |

    # Start dynamic inventory with the metadata
    { _meta: { hostvars: . } } +

    # Group all the hosts
    { all: { hosts: keys } } +

    # Group all the hosts
    { localhost_all: { hosts: keys } } +

    # Return the dynamic inventory
    {};

[ { Host: $hostname, User: "ubuntu", HostName: "localhost" } ] | into_ansible
