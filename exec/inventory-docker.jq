def into_ansible:
  reduce .[] as $ele ({}; .["\($ele.name)"] = $ele) |

  . as $all |

    # Start dynamic inventory with the metadata
    { _meta: { hostvars: . } } +

    # Group all the hosts
    { all: { hosts: keys } } +

    # Return the dynamic inventory
    {};

into_ansible
