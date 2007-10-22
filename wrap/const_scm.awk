#!awk -f

function get_scheme_name(c_name)
{
  scheme_name = c_name;
  gsub("_", "-", scheme_name);
  return "*" tolower(scheme_name) "*";
}


BEGIN {
}
{
  printf "\t\t%s\n", get_scheme_name($2);
}
END {
}

    
