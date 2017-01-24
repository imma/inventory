def into_ansible:
  # Reduces nodes into a map indexed by nodename.nih
  reduce .[] as $ele ({}; .["\($ele.Node).nih"] = $ele) |

  . as $all |

    # Start dynamic inventory with the metadata
    { _meta: { hostvars: . } } +

    # Group all the hosts
    { all: { hosts: keys } } +

    # Return the dynamic inventory
    {};

into_ansible
