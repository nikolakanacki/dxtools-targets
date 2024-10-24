#!/bin/bash

function normalizePath {
  local path=${1//\/.\//\/};
  while [[ $path =~ ([^/][^/]*/\.\./) ]]; do
    path=${path/${BASH_REMATCH[0]}/};
  done;
  echo $path;
}

function localizePath {
  local SOURCE="${BASH_SOURCE[0]}";
  while [ -h "$SOURCE" ]; do
    local DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )";
    SOURCE="$(readlink "$SOURCE")";
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE";
  done;
  echo $(normalizePath "$(cd -P "$(dirname "$SOURCE")" && pwd)/$1");
}

function getEnvFiles {
  printf ".env.default";
  if ! [ -z "$1" ]; then
    printf " .env.$1";
    printf " .env.$1.local";
  fi;
  if ! [ -z "$2" ]; then
    printf " .env.$2";
    printf " .env.$2.local";
    if ! [ -z "$1" ]; then
      printf " .env.$2.$1";
      printf " .env.$2.$1.local";
    fi;
  fi;
  printf " .env";
}

if [ "$1" == '--version' ] || [ "$1" == '-v' ]; then
  cat $(localizePath ./package.json) \
  | grep '"version":' \
  | awk '{ print $2 }' \
  | sed 's/[",]//g';
  exit 0;
fi;

[ -f .dxtools ] && source .dxtools;

if [ -z "$DXTOOLS_PROJECT_ORGANIZATION" ]; then
  DXTOOLS_PROJECT_ORGANIZATION="${npm_package_organization}";
fi;
export DXTOOLS_PROJECT_ORGANIZATION="${DXTOOLS_PROJECT_ORGANIZATION}";

if [ -z "$DXTOOLS_PROJECT_NAME" ]; then
  DXTOOLS_PROJECT_NAME="${npm_package_name}";
fi;
export DXTOOLS_PROJECT_NAME="${DXTOOLS_PROJECT_NAME}";

if [ -z "$DXTOOLS_PROJECT_TARGET" ]; then
  DXTOOLS_PROJECT_TARGET="${npm_package_dxtoolsDefaultTarget}";
fi;
export DXTOOLS_PROJECT_TARGET="${DXTOOLS_PROJECT_TARGET}";

if [ -z "$DXTOOLS_ENV" ]; then
  export DXTOOLS_ENV='development';
fi;

if [ -z "$DXTOOLS_ENV_LOADED" ]; then
  export DXTOOLS_ENV_LOADED='false';
fi;

if [ -z "$DXTOOLS_CWD" ]; then
  export DXTOOLS_CWD='./';
fi;

function printHelp {
  cat <<EOF | node
  const fs = require('fs');
  const h2t = require('html-to-text');
  const format = require('html-to-text/lib/formatter');
  const showdown = require('showdown');
  const converter = new showdown.Converter({
    disableForced4SpacesIndentedSublists: true,
    simpleLineBreaks: true,
  });

  process.stdout.write(
    \`\${
      h2t.fromString(
        converter.makeHtml(fs.readFileSync('`localizePath $1`', 'utf8')),
        {
          singleNewLineParagraphs: true,
          wordwrap: 79,
          format: {
            unorderedList: (elem, fn, options) => {
              return \`\n\${format.unorderedList(elem, fn, options)}\`;
            },
            orderedList: (elem, fn, options) => {
              return \`\n\${format.orderedList(elem, fn, options)}\`;
            },
            blockquote: (elem, fn, options) => {
              return \`\n\n> \${\`\${fn(elem.children, options)}\`.trim()}\n\n\`;
            },
            heading: (elem, fn, options) => {
              return \`\n\n\${format.heading(elem, fn, options)}\n\n\`;
            },
          },
        }
      )
      .replace(/(^[\t ]+$)/gm, '\n')
      .replace(/\n{2,}/g, '\n\n')
      .replace(/^\n+|\n+$/, '\n')
    }\n\n\`,
    () => process.exit(0),
  );
EOF
}

if [ -z "$DXTOOLS_EXECUTABLE" ]; then
  export DXTOOLS_EXECUTABLE=$(localizePath index.sh);
fi;

while test $# -gt 0; do
  ARG_COMMAND="$1"; shift;
  case $ARG_COMMAND in
    '-ed')
      DXTOOLS_ENV='development';
      DXTOOLS_ENV_LOADED='false';
    ;;
    '-ep')
      DXTOOLS_ENV='production';
      DXTOOLS_ENV_LOADED='false';
    ;;
    '-es')
      DXTOOLS_ENV='staging'
      DXTOOLS_ENV_LOADED='false';
    ;;
    '-e'|'--env')
      DXTOOLS_ENV="$1";
      shift;
    ;;
    '-o'|'--org'|'--organization')
      DXTOOLS_PROJECT_ORGANIZATION="$1";
      shift;
    ;;
    '-n'|'--name')
      DXTOOLS_PROJECT_NAME="$1";
      shift;
    ;;
    '-t'|'--target')
      DXTOOLS_PROJECT_TARGET="$1";
      shift;
    ;;
    '-d'|'--cd')
      DXTOOLS_CWD="$1";
      DXTOOLS_ENV_LOADED='false';
      shift;
    ;;
    '--no-env')
      DXTOOLS_ENV_LOADED='true';
    ;;
    '--help'|'-h')
      printHelp "./README.md";
      exit 0;
    ;;
    *)
      if [ -z "$DXTOOLS_PROJECT_ORGANIZATION" ]; then
        DXTOOLS_PROJECT_ORGANIZATION="${npm_package_organization}";
      fi;
      export DXTOOLS_PROJECT_ORGANIZATION="${DXTOOLS_PROJECT_ORGANIZATION}";

      if [ -z "$DXTOOLS_PROJECT_NAME" ]; then
        DXTOOLS_PROJECT_NAME="${npm_package_name}";
      fi;
      export DXTOOLS_PROJECT_NAME="${DXTOOLS_PROJECT_NAME}";

      if [ -z "$DXTOOLS_PROJECT_TARGET" ]; then
        DXTOOLS_PROJECT_TARGET="${npm_package_dxtoolsDefaultTarget}";
      fi;

      export DXTOOLS_PROJECT_TARGET="${DXTOOLS_PROJECT_TARGET}";

      if [ -z "$DXTOOLS_PROJECT_ORGANIZATION" ]; then
        echo '=> Error: DXTOOLS_PROJECT_ORGANIZATION or package.json > organization is missing or invalid';
        exit 1;
      fi;
      if [ -z "$DXTOOLS_PROJECT_NAME" ]; then
        echo '=> Error: DXTOOLS_PROJECT_NAME or package.json > name is missing or invalid';
        exit 1;
      fi;
      if [ -z "$DXTOOLS_PROJECT_TARGET" ]; then
        export DXTOOLS_PROJECT_TARGET_SUFFIX="";
        # echo '=> Error: DXTOOLS_PROJECT_TARGET or package.json > dxtoolsDefaultTarget is missing or invalid';
        # exit 1;
      else
        export DXTOOLS_PROJECT_TARGET_SUFFIX="-${DXTOOLS_PROJECT_TARGET}";
      fi;

      export DXTOOLS_ENV_FILES="$(getEnvFiles $DXTOOLS_ENV $DXTOOLS_PROJECT_TARGET)";

      touch $DXTOOLS_ENV_FILES;

      if [ "$DXTOOLS_ENV_LOADED" != 'true' ]; then
        vars=$(
          cat $DXTOOLS_ENV_FILES \
          2>/dev/null | xargs
        );
        if ! [ -z "$vars" ]; then
          export $vars;
        fi;
        export DXTOOLS_ENV_LOADED='true';
      fi;
      cd "$DXTOOLS_CWD";

      # echo "
      #   DXTOOLS_PROJECT_ORGANIZATION: $DXTOOLS_PROJECT_ORGANIZATION
      #   DXTOOLS_PROJECT_NAME: $DXTOOLS_PROJECT_NAME
      #   DXTOOLS_PROJECT_TARGET: $DXTOOLS_PROJECT_TARGET
      #   DXTOOLS_ENV: $DXTOOLS_ENV
      #   DXTOOLS_ENV_LOADED: $DXTOOLS_ENV_LOADED
      #   DXTOOLS_CWD: $DXTOOLS_CWD

      #   MOCK_NOTIFICATIONS_EMAIL: $MOCK_NOTIFICATIONS_EMAIL
      # ";

      # exit 1;

      case $ARG_COMMAND in
        'eval')
          if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
            shift;
            printHelp "./commands/${ARG_COMMAND}.md";
            exit 0;
          else
            if eval "$@"; then
              exit 0;
            else
              exit 1;
            fi;
          fi;
        ;;
        'shell')
          TMP_RC_FILE=$(mktemp);
          if [ -f ~/.bash_profile ]; then
            echo 'source ~/.bash_profile' >> $TMP_RC_FILE;
          fi;
          if [ -f ~/.bashrc ]; then
            echo 'source ~/.bashrc' >> $TMP_RC_FILE;
          fi;
          echo 'PS1="${PS1}(\[\e[36m\]${DXTOOLS_PROJECT_TARGET}\[\e[0m\]:${DXTOOLS_ENV}) ";' >> $TMP_RC_FILE;
          echo "rm -f $TMP_RC_FILE" >> $TMP_RC_FILE;
          stty rows $(stty size | cut -d' ' -f1) cols $(stty size | cut -d' ' -f2);
          bash --rcfile $TMP_RC_FILE;
          rm -rf $TMP_RC_FILE;
          exit 0;
        ;;
        'generate'|'docker'|'version'|'release')
          if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
            shift;
            printHelp "./commands/${ARG_COMMAND}.md";
            exit 0;
          else
            eval "$(localizePath ./commands/${ARG_COMMAND}.sh) $@";
            exit 0;
          fi;
        ;;
        *)
          echo "=> Error: Command does not exist: $ARG_COMMAND";
          exit 1;
        ;;
      esac;
    ;;
  esac;
done;
