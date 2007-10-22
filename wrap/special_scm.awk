#!awk -f

function get_scheme_name(c_name)
{
  scheme_name = c_name;
  gsub("_", "-", scheme_name);
  return tolower(scheme_name);
}


BEGIN {
  FS = "[\(\),;]";
}
{
  c_function_name = $1;
  scheme_function_name = get_scheme_name(c_function_name);
  print "\t\t" scheme_function_name;
}
END {
}

    
