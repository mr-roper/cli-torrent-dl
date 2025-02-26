#!/usr/bin/env bash
PS1B=$PS1

set -euo pipefail

VENV_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/torrentdl/.venv"

if [[ -d $VENV_DIR ]]; then
	while true; do
		read -p 'Delete and re-install virtualenv? [y/N]: ' choice
		# Convert $choice to lowercase to keep things clean.
		case "${choice,,}" in
			'y')
				rm -rf "$VENV_DIR"
				# Now we can proceed.
				break
			;;
			''|'n')
				exit
			;;
		esac
	done
# Not sure how this would happen.
# Maybe corruption or an accidental overwrite?
# Might as well plan for the worst.
elif [[ -e $VENV_DIR ]]; then
	printf '%s\n' 'Broken virtualenv detected. Reinstalling...'
	# Backup old venv in case it's still of some value.
	# Won't overwrite existing files.
	mv --backup=numbered "$VENV_DIR"{,.bak}
	printf '%s %s\n\n' 'Created backup of virtualenv at' "$VENV_DIR.bak"
fi

PYTHON_BIN=''
PYTHON_VERSION=[]
# Split python version into array.
IFS='.' read -r -a PYTHON_VERSION <<< "$(python3 -V | tr -d '[A-Za-z ]')"
# Latest minor version of python.
PYTHON_LAST_MINOR=11

if (( PYTHON_VERSION[1] >= 8 )); then
	PYTHON_BIN='python3'
else
	for (( i = PYTHON_LAST_MINOR; i >= 8; i-- )); do
		if [[ -n $(which python3.$i) ]]; then
			PYTHON_BIN="python3.$i"
			break
		fi
	done

	if [[ -z $PYTHON_BIN ]]; then
		printf '%s\n' 'tordl requires Python 3.8 or higher.' \
			'Please install it (on debian based systems:' \
			'$ sudo apt-get install python3.8)'
		exit 1
	fi

fi

# Get path of this script, resolving all symlinks.
SOURCE="${BASH_SOURCE[0]}"
while [[ -h $SOURCE ]]; do
	SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" > /dev/null 2>&1 && pwd)"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE = /* ]] || SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" > /dev/null 2>&1 && pwd)"

virtualenv -p $PYTHON_BIN "$VENV_DIR"

PS1=$PS1B

. "$VENV_DIR/bin/activate"
"$PYTHON_BIN" -m pip install -r "$SCRIPT_DIR/requirements.txt"

LN_CMD=('ln' '-sf' "$SCRIPT_DIR/tordl.sh")
if [[ $PATH =~ "$HOME/.local/bin" ]]; then
	LN_CMD+=("$HOME/.local/bin/tordl")
else
	LN_CMD=('sudo' "${LN_CMD[@]}" '/usr/local/bin/tordl')
fi

while true; do
	# This ugly expansion is to get the last elem of $LN_CMD in a more compatible way.
	read -p "Do you want to link tordl.sh to ${LN_CMD[${#LN_CMD[@]}-1]}? [Y/n]: " choice
	case "${choice,,}" in
		''|'y')
			"${LN_CMD[@]}"
			break
		;;
		'n')
			break
		;;
	esac
done
