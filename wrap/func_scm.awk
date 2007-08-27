#!awk -f

function get_scheme_name(c_name)
{
  scheme_name = c_name;
  sub("_", "-", scheme_name);
  return scheme_name;
}


BEGIN {
  FS = "[\(\),;]";
}
{
  # First, split the return type and function name in $1 into component parts
  # the pointer form
  where = match($1, /([_a-zA-Z0-9]* \*)([_a-zA-Z0-9]*)/, arr);
  if (where == 0) 
    # the non-pointer form
    where = match($1, /([_a-zA-Z0-9]*) ([_a-zA-Z0-9]*)/, arr);

  c_function_name = arr[2];
  scheme_function_name = get_scheme_name(c_function_name);
  print "\t\t" scheme_function_name;
}
END {
}

    
