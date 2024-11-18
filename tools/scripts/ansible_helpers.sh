#!/bin/bash

############################################################################################
#   helper functions for ./run scripts for ansible
############################################################################################

# find largest command/flag/target name length
get_max_length() {
  max_length=0
  for cmd in "${VALID_COMMANDS[@]} ${VALID_FLAGS[@]} ${VALID_OPTIONS[@]}"; do
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
  echo "Usage: $SCRIPT_PATH COMMAND [FLAGS]"
  echo ""
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
  echo "Options:"
  for opt in "${VALID_OPTIONS[@]}"; do
    IFS=':' read -r option description <<< "$opt"
    printf "  %-*s %s\n" $(get_max_length) "$option" "$description"
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
    i=1
    while IFS= read -r -d '' scriptfile; do
      scriptpath="$PROJECT_DIR/$scriptfile"
      #scriptfile=$(echo $scriptfile | sed 's/\//_/g' | sed 's/\./__/g' )
      if [ -f "$scriptpath" ]; then
        response=$( cat "$scriptpath" | grep DESCRIPTION 2>/dev/null)
        IFS='=' read -ra PARTS <<< "$response"
        if [ ${#PARTS[@]} -eq 2 ]; then
          SUBCOMMANDS_LIST+=("$scriptfile:${PARTS[1]}")
          i=$((i+1))
        else
          SUBCOMMANDS_LIST+=("$scriptfile:")
        fi
      fi
    done < <(find "$dir" -maxdepth "$depth" -type f -name "*.yml" -print0)
  done
}

# validate input against a list of valid commands
validate_commands() {
  local i=$1
  # Check if the command is in the valid commands list
  for line in "${VALID_COMMANDS[@]}"; do
    IFS=':' read -r command description <<< "$line"
    if [ "$command" == "$i" ]; then
      COMMANDS+=("$i")
      break
    fi
  done
  if [ -z "$COMMANDS" ]; then
    echo "Unknown Command '$i'"
    show_usage
    exit 1
  fi
}

# validate options against a list of valid options
validate_options() {
  local i=$1
  local j=$2

  for optionraw in "${VALID_OPTIONS[@]}"; do
    IFS=: read -ra optionspart <<< "$optionraw"
    IFS='=' read -ra OPTION_PARTS <<< "${optionspart[0]}"
    if [ "$i" == "${OPTION_PARTS[0]}" ]; then
      echo "$i=$j"
      return
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

# turn FLAGS and OPTIONS into PARAMS for ansible
make_ansible_params() {
  for flag in "${FLAGS[@]}"; do
    if [ "$flag" == "--localhost" ]; then
      LOCALCONNECTION="--connection=local"
    elif [ "$flag" == "--debug" ]; then
      DEBUG="true"
    else
      PARAMS+=("$flag")
    fi
  done
  for optionraw in "${OPTIONS[@]}"; do
    IFS="=" read -r option value <<< "$optionraw"
    if [ "$option" == "--verbose" ]; then
      PARAMS+=("-${value:0:1}$(printf 'v%.0s' $(seq 1 ${value}))")
    elif [ "$option" == "--user" ]; then
      SELECTED_USER="${value}"
      PARAMS+=("--extra-vars=ansible_user=${value}")
    elif [ "$option" == "--hostname" ]; then
      PARAMS+=("--limit ${value}")
    else
      PARAMS+=("$optionraw")
    fi
  done
  if [ -z "$SELECTED_USER" ]; then
    SELECTED_USER="$USER"
  fi
}

params_has_param() {
  local param_to_test=$1
  for param in "${PARAMS[@]}"; do
    if [ "$param" == "$param_to_test" ]; then
      echo "true"
      return
    fi
  done
  echo "false"
}

number_subcommands() {
  # returns a string 
  for command in "${VALID_COMMANDS[@]}"; do
    IFS=':' read -ra PARTS <<< "$command"
    if [ "${PARTS[0]}" == "$1" ]; then
      echo "${PARTS[2]}"
      return
    fi
  done
  echo 0
}

# opinionated a way to parse out cli arguments
# Depends on magic variables VALID_COMMANDS, VALID_SUBCOMMANDS, VALID_FLAGS, VALID_OPTIONS
cli_parser() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      ###### Internal Use - for dynamic validation etc ######
      is_magic_run_script)
        echo "ansible_helper"
        exit 0
        ;;
      number_subcommands)
        # returns a string for the number of subcommands we have
        number_subcommands $2
        exit 0
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
        if [ -z "$subcommand1" ]; then
          for subcommand in "${VALID_SUBCOMMANDS[@]}"; do
            IFS=':' read -ra PARTS <<< "$subcommand"
            if [ "${PARTS[0]}" = "$currentcommand" ]; then
              SUBCOMMANDS_LIST+=("${PARTS[1]}:${PARTS[2]}")
            fi
          done
        fi
        # If no subcommands were defined lets handle the special cases
        if [ ${#SUBCOMMANDS_LIST[@]} -eq 0 ]; then
          if [ -z "$subcommand1" ]; then
            search_for_yml "playbooks:2"
          else
            search_for_yml "inventories:2"
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
          local command="${COMMANDS[0]}"
          if [ -z "$command" ]; then
            command="$1"
          fi
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
            if [ $((${#COMMANDS[@]})) -gt $(($(number_subcommands $command))) ]; then
              echo "Only one command can be specified at a time: already selected '${COMMANDS[@]}' trying to add '$1'"
              show_usage
              exit 1
            fi
            COMMANDS+=("$1")
          fi
        fi
        validate_commands $1
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
}

# ======================================================================================

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
