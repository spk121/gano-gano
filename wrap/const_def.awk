#!awk -f

function get_scheme_name(c_name)
{
  scheme_name = c_name;
  gsub("_", "-", scheme_name);
  return "*" tolower(scheme_name) "*";

}


BEGIN {
  prefix = "gucu"
}
{
  # trim anyleading whitespace
  for(i=1; i<=n_args; i++)
    sub(/^ +/, "", $(i+1));


  return_type = $1;
  c_const_name = $2;
  scheme_const_name = get_scheme_name(c_const_name);

  printf "SCM %s_%s;\n", prefix, c_const_name;
}


    
