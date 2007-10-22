function get_scheme_name(c_name)
{
  scheme_name = c_name;
  gsub("_", "-", scheme_name);
  return tolower(scheme_name);
}


BEGIN {
  FS = "[\(\),;]";
  prefix = "gucu";
}
{
  # First, split the return type and function name in $1 into component parts
  # the pointer form
  where = match($1, /([_a-zA-Z0-9]* \*)([_a-zA-Z0-9]*)/, arr);
  if (where == 0) 
    # the non-pointer form
    where = match($1, /([_a-zA-Z0-9]*) ([_a-zA-Z0-9]*)/, arr);

  return_type = arr[1];
  c_function_name = arr[2];
  scheme_function_name = get_scheme_name(c_function_name);
  n_args = NF-3;

  if(n_args == 1 && $2 ~ "void")
    n_args = 0;

  printf "\tscm_c_define_gsubr (\"%s\", %d, 0, 0, %s_%s);\n", 
    scheme_function_name, n_args, prefix, c_function_name;
}

    
