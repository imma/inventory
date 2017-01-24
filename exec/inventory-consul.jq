def into_ansible:
  # Reduces nodes into a map indexed by addres
  reduce .[] as $ele ({}; .["\($ele.Address)"] = $ele) |

  . as $all |

    # Start dynamic inventory with the metadata
    { _meta: { hostvars: . } } +

    # Group all the hosts
    { all: { hosts: keys } } +

    # Return the dynamic inventory
    {};

into_ansible
