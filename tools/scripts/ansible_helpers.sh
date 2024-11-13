#!/bin/bash

############################################################################################
#   helper functions for ./run scripts for ansible
############################################################################################

# find largest command/flag/target name length
get_max_length() {
  max_length=0
  for cmd in "${VALID_COMMANDS[@]} ${VALID_FLAGS[@]} ${VALID_TARGETS[@]}"; do
    IFS=':' read -r command description <<< "$cmd"
    if [ ${#command} -gt $max_length ]; then
      max_length=${#command}
    fi
  done
  echo $((max_length+4))
}

# Modify a Cargo.toml file to set the version from --version option
update_cargo_toml() {
  for option in "${OPTIONS[@]}"; do
    if [ ! -z "$(echo $option | grep '--version')" ]; then
      version=$(echo $option | sed 's/--version=//')
      echo "Changing version in Cargo.toml to $version"
      sed -i "s/^version = \"[0-9\.]*\"/version = \"${version}\"/" Cargo.toml
      break
    fi
  done
}

# Function to display usage information
show_usage() {
  echo ""
  if [ -z "$VALID_TARGETS" ]; then
    echo "Usage: $SCRIPT_PATH COMMAND [FLAGS]"
    echo ""
  else
    echo "Usage: $SCRIPT_PATH TARGET COMMAND [FLAGS]"
    echo ""
    echo "Targets:"
    for cmd in "${VALID_TARGETS[@]}"; do
      IFS=':' read -r command description <<< "$cmd"
      printf "  %-*s %s\n" $(get_max_length) "$command" "$description"
    done
  fi
  echo "Commands:"
  for cmd in "${VALID_COMMANDS[@]}"; do
    IFS=':' read -r command description <<< "$cmd"
    printf "  %-*s %s\n" $(get_max_length) "$command" "$description"
  done
  echo "Flags:"
  for flg in "${VALID_FLAGS[@]}"; do
    IFS=':' read -r flags description <<< "$flg"
    printf "  %-*s %s\n" $(get_max_length) "$flags" "$description"
  done
}

# Allows --dryrun to not actually run the commands
# also allows --verbose to show the commands being run
run_command() {
  local command="$1"
  if [ ! -z "$(parse_flags '--dryrun')" ] || [ ! -z "$(parse_flags '--verbose')" ]; then
    local LPWD=$(pwd)
    local PWD="${LPWD#$PROJECT_DIR}"
    if [ ! -z "$(parse_flags '--dryrun')" ]; then
      echo "    Would have run '$command' from '$PWD'"
    else
      echo "    Running '$command' from '$PWD'"
    fi
  fi
  if [ -z "$(parse_flags '--dryrun')" ]; then
    eval "$command"
  fi
}

# Iterate through the targets and commands and query their valid options lists
generate_combined_optionslist() {
  VALID_OPTIONS=()
  for target in "${TARGETS[@]}"; do
    local fixed_target=${target#./}
    fixed_target=${fixed_target%/run}
    for command in "${COMMANDS[@]}"; do
      while IFS= read -r line; do
        IFS=":" read -r option validcommand description <<< "$line"
        if [ "$command" == "$validcommand" ]; then
          local option_found=false
          for valid_option in "${VALID_OPTIONS[@]}"; do
            if [ "$option" == "$valid_option" ]; then
              option_found=true
              break
            fi
          done
          if [ "$option_found" == false ]; then
            VALID_OPTIONS+=("$line")
          fi
        fi
      done < <($PROJECT_DIR/$target/run list_valid_options $command)
    done
  done
}

# accepts a CSV list with directory_to_search:depth_to_search
search_for_yml() {
  local input_list="$1"
  IFS=',' read -ra pairs <<< "$input_list"
  for pair in "${pairs[@]}"; do
    IFS=':' read -r dir depth <<< "$pair"
    depth=$((depth + 1))
    #echo $(find "./$dir" -maxdepth "$depth" -type f -name "run" -print0)
    while IFS= read -r -d '' scriptfile; do
      scriptpath="$PROJECT_DIR/$scriptfile"
      if [ -f "$scriptpath" ]; then
        response=$( cat "$scriptpath" | grep DESCRIPTION 2>/dev/null)
        IFS='=' read -ra PARTS <<< "$response"
        if [ ${#PARTS[@]} -eq 2 ]; then
          SUBCOMMANDS_LIST+=("$scriptfile:${PARTS[1]}")
        else
          SUBCOMMANDS_LIST+=("$scriptfile:")
        fi
      fi
    done < <(find "$dir" -maxdepth "$depth" -type f -name "*.yml" -print0)
  done
}

# validate options against a list of valid options
validate_options() {
  local i=$1
  local j=$2

  if [ ! -z "$VALID_TARGETS" ]; then
    generate_combined_optionslist
  fi

  is_valid_option=false
  for command in "${COMMANDS[@]}"; do
    # Check if the option is in the valid options list
    for line in "${VALID_OPTIONS[@]}"; do
      IFS=':' read -r option validcommand description <<< "$line"
      IFS='=' read -r option_name arg_type <<< "$option"
      if [ "$option_name" == "$i" ]; then
        if [ "$validcommand" == "$command" ]; then
          is_valid_option=true
          echo "$option_name=$j"
          break
        fi
      fi
    done
    if $is_valid_option; then
      break
    fi
  done
}

# find an flag in a list of valid flags
parse_flags() {
  local i=$1
  for flag in "${FLAGS[@]}"; do
    if [ "$flag" == "$i" ]; then
      echo "$1"
      break
    fi
  done
}

# find an option in a list of options
parse_options() {
  local i=$1
  for option in "${OPTIONS[@]}"; do
    IFS=':' read -r option_name argvalue <<< "$option"
    if [ "$option_name" == "$i" ]; then
      echo "$1 $argvalue"
      break
    fi
  done
}

# expand flags list
# example:
#  Having the variable set:
#    FLAGS_EXPANSIONS=("--debug:--debug --verbose")
#  replaces --debug with --debug and --verbose in FLAGS
expand_flags_list() {
  if [ -z "$FLAGS_EXPANSIONS" ]; then
    return
  fi
  for expansion in "${FLAGS_EXPANSIONS[@]}"; do
    IFS=":" read -r oldflag newflags <<< "$expansion"
    local expanded_flags=()
    for flag in "${FLAGS[@]}"; do
      if [ "$flag" == "$oldflag" ]; then
        for newflag in $newflags; do
          expanded_flags+=("$newflag")
        done
      else
        expanded_flags+=("$flag")
      fi
    done
    FLAGS=()
    for flag in "${expanded_flags[@]}"; do
      FLAGS+=("$flag")
    done
  done
}

# expand commands list
# example:
#  Having the variable set:
#    COMMAND_EXPANSIONS=("build:build compile")
#  replaces build with build and compile in COMMANDS
expand_commands_list() {
  if [ -z "$COMMAND_EXPANSIONS" ]; then
    return
  fi
  for expansion in "${COMMAND_EXPANSIONS[@]}"; do
    IFS=":" read -r oldcommand newcommands <<< "$expansion"
    if [ ! -z "$(parse_flags '--debug')" ]; then
      echo "expanding command '$oldcommand' to '$newcommands'"
    fi
    local expanded_commands=()
    for command in "${COMMANDS[@]}"; do
      if [ "$command" == "$oldcommand" ]; then
        for newcommand in $newcommands; do
          expanded_commands+=("$newcommand")
          if [ ! -z "$(parse_flags '--debug')" ]; then
            echo "adding command '$newcommand'"
          fi
        done
      else
        expanded_commands+=("$command")
      fi
    done
    COMMANDS=()
    for command in "${expanded_commands[@]}"; do
      COMMANDS+=("$command")
    done
  done
}

# opinionated a way to parse out cli arguments
# Depends on magic variables VALID_TARGETS, VALID_COMMANDS, VALID_FLAGS
cli_parser() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      ###### Internal Use - for dynamic validation etc ######
      is_magic_run_script)
        echo "ansible_helper"
        exit 0
        ;;
      number_subcommands)
        # returns a string 
        for command in "${VALID_COMMANDS[@]}"; do
          IFS=':' read -ra PARTS <<< "$command"
          if [ "${PARTS[0]}" == "$2" ]; then
            echo "${PARTS[2]}"
            exit 0
          fi
        done
        ;;
      whoami)
        # returns a string that can be used to identify the script
        # This is useful for dynamic validation of targets
        #   Note: tags should be a comma separated list of tags
        #         tags could be used to filter the list of targets in the future
        # "target:tags:description"
        SCRIPT_TARGET_PATH="${SCRIPT_PATH#./}"
        SCRIPT_TARGET_PATH="${SCRIPT_TARGET_PATH%/run}"
        if [ -z "$SCRIPT_TAGS" ]; then
          SCRIPT_TAGS="default"
        fi
        if [ -z "$SHORT_DESC" ]; then
          SHORT_DESC="Update $SHORT_DESC"
        fi
        echo "${SCRIPT_TARGET_PATH}:$SCRIPT_TAGS:$SHORT_DESC"
        exit 0
        ;;
      list_valid_commands)
        # Let's us interrogate the script for valid subcommand for zsh completion
        for command in "${VALID_COMMANDS[@]}"; do
          IFS=':' read -ra PARTS <<< "$command"
          echo "${PARTS[0]}:${PARTS[1]}"
        done
        exit 0
        ;;
      list_valid_subcommands)
        # Let's us interrogate the script for valid subcommands
        #  Given the current COMMAND, we need to find the valid subcommands to validate
        #  Also for zsh completion
        local currentcommand="$2"
        local subcommand1="$3"
        local SUBCOMMANDS_LIST=()
        # If we've defined some subcommands compare to currentcommand to see if they are relevant
        for subcommand in "${VALID_SUBCOMMANDS[@]}"; do
          IFS=':' read -ra PARTS <<< "$subcommand"
          if [ "${PARTS[0]}" = "$currentcommand" ]; then
            SUBCOMMANDS_LIST+=("${PARTS[1]}:${PARTS[2]}")
          fi
        done
        # If no subcommands were defined lets handle the special cases
        if [ ${#SUBCOMMANDS_LIST[@]} -eq 0 ]; then
          if [ "$currentcommand" == "targets" ]; then
            if [ -z "$subcommand1" ]; then
              search_for_yml "playbooks:2"
            else
              search_for_yml "inventories:2"
            fi
            
          fi
        fi
        for command in "${SUBCOMMANDS_LIST[@]}"; do
          echo "$command"
        done
        exit 0
        ;;
      list_valid_flags)
        # Let's us interrogate the script for valid flags
        #  Also for zsh completion
        for flag in "${VALID_FLAGS[@]}"; do
          echo "$flag"
        done
        exit 0
        ;;
      list_valid_options)
        # Let's us interrogate the script for valid options
        #  Also for zsh completion
        for option in "${VALID_OPTIONS[@]}"; do
          echo "$option"
        done
        exit 0
        ;;
      ##### End Internal Use ######
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        if [ ! -z "$COMMANDS" ]; then
          if [[ $1 == --* ]]; then
            # this is a flag or option
            IFS='=' read -ra OPTION_PARTS <<< "$1"
            if [ ${#OPTION_PARTS[@]} -ge 2 ]; then
              option=$(validate_options "${OPTION_PARTS[0]}" "${OPTION_PARTS[1]}")
            else
              option=$(validate_options $1 $2)
            fi
            if [ ! -z "$option" ]; then
              OPTIONS+=("$option")
              if [ ${#OPTION_PARTS[@]} -lt 2 ]; then
                shift
              fi
            else
              FLAGS+=("$1")
            fi
          else
            echo "Only one command can be specified at a time: already selected '${COMMANDS[@]}' trying to add '$1'"
            show_usage
            exit 1
          fi
        fi
        shift
        ;;
    esac
  done
  # These conditions probably are only hit if we have a bug in the the scripting
  if [ -z "$COMMANDS" ]; then
    echo "No command specified"
    show_usage
    exit 1
  fi
  #  uses FLAGS_EXPANSIONS and COMMAND_EXPANSIONS to expand the lists
  #  This is useful for things like --debug which is expanded to --debug --verbose
  expand_flags_list
  expand_commands_list
}

install_zsh_completion() {
  run_command "mkdir -p ~/.oh-my-zsh/completions"
  run_command "cp $PROJECT_DIR/tools/scripts/run.zsh_completion $HOME/.oh-my-zsh/completions/_run"
}

# Normally this is a library but we can use it as a script
#  to install the zsh completion scripts and potentially other things
#  in the future like auto-gen of new scripts to a project etc.
if [ "$0" == "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  PROJECT_DIR="$( cd $SCRIPT_DIR/../.. &> /dev/null && pwd )"
  cd "$SCRIPT_DIR"

  VALID_COMMANDS=("install_zsh:Install zsh completion scripts"
                  "help:Show help for TARGET")
  VALID_FLAGS=("--help|-h:Show help for this script"
                 "--dryrun:Dryrun.  Don't actually run the commands"
                 "--verbose:Verbose output")

  FLAGS=()
  COMMANDS=()
  # Parse command line arguments
  cli_parser $@

  for COMMAND in "${COMMANDS[@]}"; do
    case "$COMMAND" in
      install_zsh)
        install_zsh_completion
        exit 0
        ;;
      *)
        echo "command '$COMMAND' not implemented"
        show_usage
        exit 1
        ;;
    esac
  done
fi
