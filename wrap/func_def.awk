#!awk -f

function get_scheme_name(c_name)
{
  scheme_name = c_name;
  gsub("_", "-", scheme_name);
  return tolower(scheme_name);

}

BEGIN {
  FS = "[\(\),;]";
  prefix = "gucu"
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

  for(i=1;i<=NF;i++) {
    print "// " i ": " $i;
  }

  if(return_type ~ "void")
    void_func = 1;
  else
    void_func = 0;

# trim leading whitespace
  for(i=1; i<=n_args; i++)
    sub(/^ +/, "", $(i+1));

  if(n_args == 1 && $(2) ~ "void")
    n_args = 0;

  print "SCM";
  printf "%s_%s (", prefix, c_function_name;
  if(n_args>1)
    for(i=1; i<=n_args-1; i++) {
      cur_type = "SCM";
      cur_arg = "arg" i;
      if (match(cur_type, "\*"))
	printf "%s%s, ", cur_type, cur_arg;
      else
	printf "%s %s, ", cur_type, cur_arg;
    }
  if(n_args>=1) {
    cur_type = "SCM";
    cur_arg = "arg" n_args;
    if (match(cur_type, "\*"))
      printf "%s%s", cur_type, cur_arg;
    else
      printf "%s %s", cur_type, cur_arg;
  }
  printf ")\n";
  printf "{\n";

# INPUT CHECKING
  for(i=1; i<=n_args; i++) {
    cur_type = $(i+1);
    cur_arg = "arg" i;
    # print "type :\"" cur_type "\" arg :\"" cur_arg "\"";
    switch (cur_type) {
    case "attr_t":
    case "const attr_t":
      test_func = "_scm_is_attr";
      break;
    case "bool":
      test_func = "scm_is_bool";
      break;
    case "cstring_t *":
    case "const cstring_t *":
      test_func = "_scm_is_cstring";
      break;
    case "cchar_t *":
    case "const cchar_t *":
      test_func = "_scm_is_cchar";
      break;
    case "char":
      test_func = "scm_is_integer";
      break;
    case "char *":
    case "const char *":
      test_func = "scm_is_string";
      break;
    case "chtype":
    case "const chtype":
      test_func = "_scm_is_chtype";
      break;
    case "chtype *":
    case "const chtype *":
      test_func = "_scm_is_chstring";
      break;
    case "FIELD *":
    case "const FIELD *":
      test_func = "_scm_is_field";
      break;
    case "FILE *":
      test_func = "_scm_is_file";
      break;
    case "FORM *":
    case "const FORM *":
      test_func = "_scm_is_form";
      break;
    case "int":
      test_func = "scm_is_integer";
      break;
    case "MENU *":
    case "const MENU *":
      test_func = "_scm_is_menu";
      break;
    case "PANEL *":
    case "const PANEL *":
      test_func = "_scm_is_panel";
      break;
    case "SCREEN *":
      test_func = "_scm_is_screen";
      break;
    case "short":
      test_func = "scm_is_integer";
      break;
    case "void *":
    case "const void *":
      test_func = "_scm_is_voidstring";
      break;
    case "wchar_t":
    case "const wchar_t":
      test_func = "_scm_is_wchar";
      break;
    case "wchar_t *":
    case "const wchar_t *":
      test_func = "_scm_is_wchar_string";
      break;
    case "const wint_t *":
      test_func = "_scm_is_wint_string";
      break;
    case "WINDOW *":
    case "const WINDOW *":
      test_func = "_scm_is_window";
      break;
    default:
      test_func = "_scm_blammo";
    }
    if (i < 8)
      printf "\tSCM_ASSERT (%s (%s), %s, SCM_ARG%d, \"%s\");\n", 
	test_func, cur_arg, cur_arg, i, scheme_function_name;
    else
      printf "\tSCM_ASSERT (%s (%s), %s, %d, \"%s\");\n", 
	test_func, cur_arg, cur_arg, i, scheme_function_name;
      
  } 
  if (n_args)
    print "";  

# MALLOC

# ASSIGN
  for(i=1; i<=n_args; i++) {
    cur_type = $(i+1);
    cur_arg = "arg" i;
    cur_c_arg = "c_" cur_arg;
    # print "// type :\"" cur_type "\" arg :\"" cur_arg "\"";
    switch (cur_type) {
    case "attr_t":
    case "const attr_t":
      assign_func = "_scm_to_attr";
      break;
    case "bool":
      assign_func = "scm_to_bool";
      break;
    case "cchar_t *":
    case "const cchar_t *":
      assign_func = "_scm_to_cchar";
      break;
    case "cstring_t *":
    case "const cstring_t *":
      assign_func = "_scm_to_cstring";
      break;
    case "char":
      assign_func = "scm_to_char";
      break;
    case "char *":
    case "const char *":
      assign_func = "scm_to_locale_string";
      break;
    case "chtype":
    case "const chtype":
      assign_func = "_scm_to_chtype";
      break;
    case "chtype *":
    case "const chtype *":
      assign_func = "_scm_to_chstring";
      break;
    case "int":
      assign_func = "scm_to_int";
      break;
    case "FIELD *":
    case "const FIELD *":
      assign_func = "_scm_to_field";
      break;
    case "FILE *":
      assign_func = "_scm_to_file";
      break;
    case "FORM *":
    case "const FORM *":
      assign_func = "_scm_to_form";
      break;
    case "MENU *":
    case "const MENU *":
      assign_func = "_scm_to_menu";
      break;
    case "PANEL *":
    case "const PANEL *":
      assign_func = "_scm_to_panel";
      break;
    case "SCREEN *":
      assign_func = "_scm_to_screen";
      break;
    case "short":
      assign_func = "scm_to_short";
      break;
    case "void *":
    case "const void *":
      assign_func = "_scm_to_voidstring";
      break;
    case "WINDOW *":
    case "const WINDOW *":
      assign_func = "_scm_to_window";
      break;
    case "wchar_t":
    case "const wchar_t":
      assign_func = "_scm_to_wchar";
      break;
    case "wchar_t *":
    case "const wchar_t *":
      assign_func = "_scm_to_wchar_string";
      break;
    case "wint_t":
      assign_func = "_scm_to_wint";
      break;
    case "wint_t *":
    case "const wint_t *":
      assign_func = "_scm_to_wint_string";
      break;
    default:
      assign_func = "_scm_to_blammo";
    }

    if (match(cur_type, "\*"))
      if (match(cur_type, "const")) {
	noconst_cur_type = cur_type;
	sub(/const/, "", noconst_cur_type);
	printf "\t%s%s = %s (%s);\n", noconst_cur_type, cur_c_arg, assign_func, cur_arg;
      } else {
	printf "\t%s%s = %s (%s);\n", cur_type, cur_c_arg, assign_func, cur_arg;
      }
    else
      printf "\t%s %s = %s (%s);\n", cur_type, cur_c_arg, assign_func, cur_arg;
  } 
  if (n_args)
    print "";

# CALL
  if (void_func)
    printf "\t %s (", c_function_name;
  else
    printf "\t%s ret = %s (", return_type, c_function_name;
  if(n_args>1) {
    for(i=1; i<=n_args-1; i++) {
      cur_c_arg = "c_arg" i;
      printf "%s, ", cur_c_arg;
    }
  }
  if(n_args>=1) {
    cur_c_arg = "c_arg" n_args;
    printf "%s", cur_c_arg;
  }
  printf ");\n";


  switch (return_type) {
  case "attr_t":
    assign_func = "_scm_from_attr";
    break;
  case "bool":
    assign_func = "scm_from_bool";
    break;
  case "char":
    assign_func = "scm_from_char";
    break;
  case "char *":
    assign_func = "scm_from_locale_string";
    break;
  case "cchar_t *":
  case "const cchar_t *":
    assign_func = "_scm_from_cchar";
    break;
  case "cstring_t *":
  case "const cstring_t *":
    assign_func = "_scm_from_cstring";
    break;
  case "const chtype":
  case "chtype":
    assign_func = "_scm_from_chtype";
    break;
  case "const chtype *":
    assign_func = "_scm_from_chstring";
    break;
  case "FIELD *":
  case "const FIELD *":
    assign_func = "_scm_from_field";
    break
      case "FILE *":
      assign_func = "_scm_from_file";
    break;
  case "FORM *":
  case "const FORM *":
    assign_func = "_scm_from_form";
    break;
  case "int":
    assign_func = "scm_from_int";
    break;
  case "MENU *":
  case "const MENU *":
    assign_func = "_scm_from_menu";
    break;
  case "PANEL *":
  case "const PANEL *":
    assign_func = "_scm_from_panel";
    break;
  case "SCREEN *":
    assign_func = "_scm_from_screen";
    break;
  case "short":
    assign_func = "scm_from_short";
    break;
  case "WINDOW *":
    assign_func = "_scm_from_window";
    break;
  case "wchar_t":
  case "const wchar_t":
    assign_func = "_scm_from_wchar";
    break;
  case "wchar_t *":
  case "const wchar_t *":
    assign_func = "_scm_from_wchar_string";
    break;
  case "wint_t":
    assign_func = "_scm_from_wint";
    break;
  case "wint_t *":
  case "const wint_t *":
    assign_func = "_scm_from_wint_string";
    break;
  default:
    assign_func = "_scm_from_blammo";
  }
  if (void_func)
    printf "\tSCM s_ret = SCM_UNSPECIFIED;\n";
  else
    printf "\tSCM s_ret = %s (ret);\n", assign_func;
  print "";

# FREE
  n_freed = 0;
  for(i=1; i<=n_args; i++) {
    cur_type = $(i+1);
    cur_arg = "arg" i;
    cur_c_arg = "c_" cur_arg;
    switch (cur_type) {
    case "const cchar_t *":
    case "const cstring_t *":
    case "const char *":
    case "const chtype *":
    case "const wchar_t *":
    case "const wint_t *":
      printf "\tfree (%s);\n", cur_c_arg;
      n_freed += 1;
      break;
    default:
      break;
    }
  } 
  if (n_freed > 0)
    print "";

    
# RETURN
  printf "\treturn s_ret;\n";
  print "}";
  print "";
    
}


    
