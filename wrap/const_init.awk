#!awk -f

function get_scheme_name(c_name)
{
  scheme_name = c_name;
  gsub("_", "-", scheme_name);
  return scheme_name;

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

  printf "\t%s_%s = scm_permanent_object (scm_c_define (", prefix, c_const_name;
  printf "\"%s\", ", scheme_const_name;
  switch (return_type) {
  case "int":
    type_func = "scm_from_int";
    break;
  case "chtype":
    type_func = "_scm_from_chtype";
    break;
  case "attr_t":
    type_func = "_scm_from_attr";
    break;
  default:
    type_func = "scm_from_blammo";
  }
  printf "%s (%s)", type_func, c_const_name;
  printf "));\n"

}


    
