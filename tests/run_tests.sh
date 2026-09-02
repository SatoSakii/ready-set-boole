#!/usr/bin/env bash
#
# tests/run_tests.sh — suite de tests fonctionnels pour ready-set-boole
#
# Chaque binaire est teste en boite noire : on lance ./exNN/exNN et on compare
# la sortie (debarrassee des codes ANSI).
#
# Point important : pour les exercices logiques (ex03..ex07) les attendus ne
# sont pas recopies a la main depuis la sortie du programme, ils sont recalcules
# par un evaluateur RPN de reference ecrit en bash (ref_eval / ref_table).
# Un bug dans l'AST C++ ne peut donc pas se "cacher" dans les attendus.
# Pour ex10/ex11 l'oracle est un awk independant qui refait l'entrelacement.
#
# Usage :  make test        (ou)  bash tests/run_tests.sh [-v] [--leaks]
#   -v       : affiche le nom de chaque test au lieu du compteur.
#   --leaks  : ajoute l'audit memoire (leaks --atExit sur macOS, valgrind sur
#              Linux). Hors du run par defaut car c'est lent.

LC_ALL=C
export LC_ALL

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

VERBOSE=""
LEAKS=""
for arg in "$@"; do
	case "$arg" in
		-v|--verbose) VERBOSE=1 ;;
		--leaks) LEAKS=1 ;;
		*) printf 'option inconnue : %s\n' "$arg" >&2; exit 1 ;;
	esac
done

TTY=""
[ -t 1 ] && [ -z "$VERBOSE" ] && TTY=1

# garde-fou : aucune invocation ne doit pouvoir bloquer la suite.
# La CNF par distribution peut exploser sur les formules tres imbriquees.
TIMEOUT=""
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT="timeout 10"
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT="gtimeout 10"
fi

if [ -t 1 ]; then
	RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
	CYAN=$'\033[36m'; GRAY=$'\033[90m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
	RED=""; GREEN=""; YELLOW=""; CYAN=""; GRAY=""; BOLD=""; RESET=""
fi

# ---------------------------------------------------------------- infrastructure

PASS=0
FAIL=0
S_PASS=0
S_FAIL=0
S_NAME=""

FAILLOG="$(mktemp "${TMPDIR:-/tmp}/rsb-fail.XXXXXX")"
trap 'rm -f "$FAILLOG"' EXIT

strip_ansi()
{
	sed 's/'$'\033''\[[0-9;]*m//g'
}

# run <cmd> [args...] : remplit OUT (stdout+stderr sans ANSI) et RC
OUT=""
RC=0
run()
{
	OUT="$($TIMEOUT "$@" 2>&1)"
	RC=$?
	OUT="$(printf '%s' "$OUT" | strip_ansi)"
}

# valeur affichee apres la fleche des macros RESULT/ERROR/USAGE
val()
{
	printf '%s' "${OUT##*$'\xe2\x86\x92' }"
}

# derniere ligne de la sortie (ex08 imprime le powerset sous la ligne RESULT,
# ex09 imprime l'ensemble sans prefixe)
lastline()
{
	printf '%s' "${OUT##*$'\n'}"
}

_dump()
{
	# $'\n' et pas $(printf '\n') : la substitution de commande mange les
	# retours a la ligne finaux et le motif deviendrait *""* (= tout).
	case "$2" in
		*$'\n'*)
			printf '        %s :\n' "$1" >> "$FAILLOG"
			printf '%s\n' "$2" | sed 's/^/          /' >> "$FAILLOG"
			;;
		*)
			printf '        %-8s : %s\n' "$1" "$2" >> "$FAILLOG"
			;;
	esac
}

section()
{
	[ -n "$S_NAME" ] && section_end
	S_NAME="$1"
	S_PASS=0
	S_FAIL=0
	S_START=$SECONDS
	: > "$FAILLOG"
	progress
}

# compteur reecrit sur place : une seule ligne par section, jamais de
# ribambelle de points qui deborde du terminal.
progress()
{
	[ -n "$TTY" ] || return 0
	printf '\r  %s%-26s%s %s%s tests%s\033[K' \
		"$BOLD$CYAN" "$S_NAME" "$RESET" "$GRAY" "$((S_PASS + S_FAIL))" "$RESET"
}

section_end()
{
	local total=$((S_PASS + S_FAIL)) mark colour

	if [ "$S_FAIL" -eq 0 ]; then
		mark="✔"
		colour="$GREEN"
	else
		mark="✖"
		colour="$RED"
	fi

	[ -n "$TTY" ] && printf '\r\033[K'
	printf '  %s%s%s %s%-26s%s %s%s/%s%s %s(%ss)%s\n' \
		"$colour" "$mark" "$RESET" "$BOLD" "$S_NAME" "$RESET" \
		"$colour" "$S_PASS" "$total" "$RESET" \
		"$GRAY" "$((SECONDS - S_START))" "$RESET"

	if [ "$S_FAIL" -gt 0 ]; then
		cat "$FAILLOG"
	fi
	S_NAME=""
}

check()
{
	local name="$1" expected="$2" actual="$3"

	if [ "$expected" = "$actual" ]; then
		PASS=$((PASS + 1))
		S_PASS=$((S_PASS + 1))
		if [ -n "$VERBOSE" ]; then
			printf '    %sok%s %s\n' "$GREEN" "$RESET" "$name"
		else
			progress
		fi
	else
		FAIL=$((FAIL + 1))
		S_FAIL=$((S_FAIL + 1))
		progress
		printf '      %s✖%s %s\n' "$RED" "$RESET" "$name" >> "$FAILLOG"
		_dump "attendu" "$expected"
		_dump "obtenu" "$actual"
	fi
}

# check_rc <nom> <code attendu> <code obtenu>
check_rc()
{
	check "$1 (code retour)" "$2" "$3"
}

# ---------------------------------------------------------------------- oracle
#
# Evaluateur RPN de reference, independant du C++.
#   ref_eval <formule> <variables> <bits>
# ex : ref_eval "AB&" "AB" "10"  ->  0

LETTERS=ABCDEFGHIJKLMNOPQRSTUVWXYZ
OPS='&|^>='

ref_eval()
{
	local expr="$1" vars="$2" bits="$3"
	local stack="" i c a b r pre

	for (( i = 0; i < ${#expr}; i++ )); do
		c="${expr:i:1}"
		case "$c" in
			0|1)
				stack="$stack$c"
				;;
			[ABCDEFGHIJKLMNOPQRSTUVWXYZ])
				pre="${vars%%$c*}"
				stack="$stack${bits:${#pre}:1}"
				;;
			'!')
				a="${stack: -1}"
				stack="${stack%?}"
				stack="$stack$((1 - a))"
				;;
			*)
				b="${stack: -1}"
				stack="${stack%?}"
				a="${stack: -1}"
				stack="${stack%?}"
				case "$c" in
					'&') r=$((a & b)) ;;
					'|') r=$((a | b)) ;;
					'^') r=$((a ^ b)) ;;
					'>') r=$(((1 - a) | b)) ;;
					'=') if [ "$a" = "$b" ]; then r=1; else r=0; fi ;;
				esac
				stack="$stack$r"
				;;
		esac
	done
	printf '%s' "$stack"
}

# variables presentes dans la formule, triees, sans doublon (comme extractVariables)
ref_vars()
{
	local f="$1" v="" i c

	for (( i = 0; i < 26; i++ )); do
		c="${LETTERS:i:1}"
		case "$f" in
			*"$c"*) v="$v$c" ;;
		esac
	done
	printf '%s' "$v"
}

# table de verite de reference, au format exact de ex04
ref_table()
{
	local expr="$1" vars n rows i k bits res line

	vars="$(ref_vars "$expr")"
	n=${#vars}

	line=""
	for (( k = 0; k < n; k++ )); do
		line="$line| ${vars:k:1} "
	done
	printf '%s| = |\n' "$line"

	line=""
	for (( k = 0; k <= n; k++ )); do
		line="$line|---"
	done
	printf '%s|\n' "$line"

	rows=$((1 << n))
	for (( i = 0; i < rows; i++ )); do
		bits=""
		for (( k = 0; k < n; k++ )); do
			bits="$bits$(((i >> (n - k - 1)) & 1))"
		done
		res="$(ref_eval "$expr" "$vars" "$bits")"
		line=""
		for (( k = 0; k < n; k++ )); do
			line="$line| ${bits:k:1} "
		done
		printf '%s| %s |\n' "$line" "$res"
	done
}

# satisfiabilite de reference : au moins une ligne a 1 dans la table
ref_sat()
{
	# grep -c (et pas -q) : -q sort au premier match et casse le tube que
	# ref_table est en train d'ecrire ("write error: Broken pipe").
	if [ "$(ref_table "$1" | grep -c '| 1 |$')" -gt 0 ]; then
		printf 'true'
	else
		printf 'false'
	fi
}

# ------------------------------------------------------- validateurs de forme
#
# Types empiles : A = atome, L = litteral nie, X = sous-formule quelconque,
#                 C = clause (disjonction de litteraux), F = conjonction.

# forme NNF valide : ni ^ ni > ni =, et chaque ! porte sur un atome
nnf_shape()
{
	local expr="$1" stack="" i c t

	for (( i = 0; i < ${#expr}; i++ )); do
		c="${expr:i:1}"
		case "$c" in
			[01ABCDEFGHIJKLMNOPQRSTUVWXYZ])
				stack="${stack}A"
				;;
			'!')
				t="${stack: -1}"
				stack="${stack%?}"
				[ "$t" = "A" ] || { printf 'negation-non-atomique'; return; }
				stack="${stack}L"
				;;
			'&'|'|')
				[ ${#stack} -ge 2 ] || { printf 'pile-invalide'; return; }
				stack="${stack%??}X"
				;;
			*)
				printf 'operateur-interdit:%s' "$c"
				return
				;;
		esac
	done
	if [ ${#stack} -eq 1 ]; then printf 'nnf'; else printf 'pile-invalide'; fi
}

# forme CNF valide : conjonction de disjonctions de litteraux
cnf_shape()
{
	local expr="$1" stack="" i c t a b

	for (( i = 0; i < ${#expr}; i++ )); do
		c="${expr:i:1}"
		case "$c" in
			[01ABCDEFGHIJKLMNOPQRSTUVWXYZ])
				stack="${stack}A"
				;;
			'!')
				t="${stack: -1}"
				stack="${stack%?}"
				[ "$t" = "A" ] || { printf 'negation-non-atomique'; return; }
				stack="${stack}L"
				;;
			'|')
				[ ${#stack} -ge 2 ] || { printf 'pile-invalide'; return; }
				b="${stack: -1}"; stack="${stack%?}"
				a="${stack: -1}"; stack="${stack%?}"
				case "$a$b" in
					*F*) printf 'et-sous-un-ou'; return ;;
				esac
				stack="${stack}C"
				;;
			'&')
				[ ${#stack} -ge 2 ] || { printf 'pile-invalide'; return; }
				stack="${stack%??}F"
				;;
			*)
				printf 'operateur-interdit:%s' "$c"
				return
				;;
		esac
	done
	if [ ${#stack} -eq 1 ]; then printf 'cnf'; else printf 'pile-invalide'; fi
}

# ------------------------------------------------------ generateur de formules

# rand_formula <atomes> <etapes> : formule RPN valide pseudo-aleatoire.
# Le resultat est pose dans la globale FORMULA et *pas* renvoye sur stdout :
# une substitution de commande cree un sous-shell, et bash y reensemence
# RANDOM a partir du PID. Passer par $(...) rendait donc le fuzz
# non reproductible d'un run a l'autre (et parfois tres lent, quand le tirage
# tombait sur des '=' imbriques dont la CNF explose).
FORMULA=""
rand_formula()
{
	local atoms="$1" steps="$2" out="" depth=0 i r na

	na=${#atoms}
	for (( i = 0; i < steps; i++ )); do
		if [ "$depth" -lt 2 ]; then r=0; else r=$((RANDOM % 4)); fi
		case "$r" in
			0|3)
				out="$out${atoms:$((RANDOM % na)):1}"
				depth=$((depth + 1))
				;;
			1)
				out="$out!"
				;;
			2)
				out="$out${OPS:$((RANDOM % ${#OPS})):1}"
				depth=$((depth - 1))
				;;
		esac
	done
	while [ "$depth" -gt 1 ]; do
		out="$out${OPS:$((RANDOM % ${#OPS})):1}"
		depth=$((depth - 1))
	done
	FORMULA="$out"
}

# Au-dela de cette taille, l'oracle bash devient trop lent pour etre utile
# (${str:i:1} est O(i), donc le parseur est quadratique). Les formules plus
# grosses sont verifiees par un controle bon marche a la place.
ORACLE_MAX=2000

# ------------------------------------------------------------- oracle ex10/ex11

MAXU32=4294967295

# entrelacement de reference (x sur les bits pairs, y sur les bits impairs)
awk_interleave()
{
	awk -v x="$1" -v y="$2" 'BEGIN {
		v = 0
		for (i = 0; i < 16; i++) {
			p = 2 ^ i
			if (int(x / p) % 2) v += 2 ^ (2 * i)
			if (int(y / p) % 2) v += 2 ^ (2 * i + 1)
		}
		printf "%d", v
	}'
}

# valeur telle que ex10 doit l'afficher (setprecision(max_digits10) == %.17g)
awk_map()
{
	awk -v v="$(awk_interleave "$1" "$2")" -v m="$MAXU32" \
		'BEGIN { printf "%.17g", v / m }'
}

# ------------------------------------------------------------- pre-requis

MISSING=""
for e in ex00 ex01 ex02 ex03 ex04 ex05 ex06 ex07 ex08 ex09 ex10 ex11; do
	[ -x "$e/$e" ] || MISSING="$MISSING $e"
done
if [ -n "$MISSING" ]; then
	printf '%sBinaires manquants :%s%s\n' "$RED" "$MISSING" "$RESET"
	printf 'Lance "make" avant de lancer les tests.\n'
	exit 1
fi

printf '\n%s%sready-set-boole — tests fonctionnels%s\n\n' "$BOLD" "$CYAN" "$RESET"

# ============================================================== ex00 : adder

section "ex00 adder"

for a in 0 1 2 3 5 8; do
	for b in 0 1 2 3 5 8; do
		run ./ex00/ex00 "$a" "$b"
		check "$a + $b" "$((a + b))" "$(val)"
	done
done

# bornes et debordement sur 32 bits non signes
check_ovf()
{
	run ./ex00/ex00 "$1" "$2"
	check "$1 + $2 (mod 2^32)" "$(( ($1 + $2) & MAXU32 ))" "$(val)"
}
check_ovf 4294967295 0
check_ovf 4294967295 1
check_ovf 4294967295 4294967295
check_ovf 2147483648 2147483648
check_ovf 2147483647 1
check_ovf 1 4294967294
check_ovf 65535 65535
check_ovf 305419896 2271560481

# commutativite
run ./ex00/ex00 123 456; A1="$(val)"
run ./ex00/ex00 456 123; A2="$(val)"
check "commutativite 123/456" "$A1" "$A2"

# fuzz reproductible
RANDOM=1337
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	a=$((RANDOM * 65536 + RANDOM))
	b=$((RANDOM * 65536 + RANDOM))
	run ./ex00/ex00 "$a" "$b"
	check "fuzz $a + $b" "$(( (a + b) & MAXU32 ))" "$(val)"
done

# usage
run ./ex00/ex00
check_rc "sans argument" 1 "$RC"
run ./ex00/ex00 1
check_rc "un seul argument" 1 "$RC"
run ./ex00/ex00 1 2 3
check_rc "trois arguments" 1 "$RC"
run ./ex00/ex00 1 2
check_rc "deux arguments" 0 "$RC"

# ========================================================= ex01 : multiplier

section "ex01 multiplier"

for a in 0 1 2 3 5 7; do
	for b in 0 1 2 3 5 7; do
		run ./ex01/ex01 "$a" "$b"
		check "$a * $b" "$((a * b))" "$(val)"
	done
done

check_mul()
{
	run ./ex01/ex01 "$1" "$2"
	check "$1 * $2 (mod 2^32)" "$(( ($1 * $2) & MAXU32 ))" "$(val)"
}
check_mul 0 4294967295
check_mul 1 4294967295
check_mul 2 4294967295
check_mul 65535 65535
check_mul 65536 65536
check_mul 2147483648 2
check_mul 12345 6789
check_mul 100000 100000
check_mul 3 1431655765

# commutativite
run ./ex01/ex01 37 91;  M1="$(val)"
run ./ex01/ex01 91 37;  M2="$(val)"
check "commutativite 37/91" "$M1" "$M2"

RANDOM=2024
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
	a=$((RANDOM % 100000))
	b=$((RANDOM % 40000))
	run ./ex01/ex01 "$a" "$b"
	check "fuzz $a * $b" "$(( (a * b) & MAXU32 ))" "$(val)"
done

run ./ex01/ex01
check_rc "sans argument" 1 "$RC"
run ./ex01/ex01 4
check_rc "un seul argument" 1 "$RC"

# ========================================================== ex02 : gray_code

section "ex02 gray_code"

# table de reference connue pour 0..15
set -- 0 1 3 2 6 7 5 4 12 13 15 14 10 11 9 8
i=0
for expected in "$@"; do
	run ./ex02/ex02 "$i"
	check "gray($i)" "$expected" "$(val)"
	i=$((i + 1))
done

# formule de reference n ^ (n >> 1) sur des valeurs plus grandes
for n in 16 31 32 63 64 100 255 256 1000 65535 65536 2147483647 2147483648 4294967295; do
	run ./ex02/ex02 "$n"
	check "gray($n)" "$((n ^ (n >> 1)))" "$(val)"
done

# propriete : deux codes consecutifs ne different que d'un bit
popcount()
{
	local v="$1" c=0
	while [ "$v" -ne 0 ]; do
		c=$((c + (v & 1)))
		v=$((v >> 1))
	done
	printf '%s' "$c"
}
for n in 0 1 2 3 6 7 14 15 16 31 100 255; do
	run ./ex02/ex02 "$n";           g1="$(val)"
	run ./ex02/ex02 "$((n + 1))";   g2="$(val)"
	check "distance de Hamming gray($n)/gray($((n + 1)))" 1 "$(popcount "$((g1 ^ g2))")"
done

# propriete : bijection sur 0..63 (aucune collision)
SEEN=""
DUP=0
for (( n = 0; n < 64; n++ )); do
	run ./ex02/ex02 "$n"
	g="$(val)"
	case " $SEEN " in
		*" $g "*) DUP=$((DUP + 1)) ;;
	esac
	SEEN="$SEEN $g"
done
check "injectivite sur 0..63" 0 "$DUP"

run ./ex02/ex02
check_rc "sans argument" 1 "$RC"
run ./ex02/ex02 1 2
check_rc "deux arguments" 1 "$RC"

# ======================================================= ex03 : eval_formula

section "ex03 eval_formula"

bool_word()
{
	if [ "$1" = "1" ]; then printf 'true'; else printf 'false'; fi
}

# les 4 combinaisons pour chacun des 5 operateurs binaires, attendus par l'oracle
for op in '&' '|' '^' '>' '='; do
	for l in 0 1; do
		for r in 0 1; do
			f="$l$r$op"
			run ./ex03/ex03 "$f"
			check "$f" "$(bool_word "$(ref_eval "$f" "" "")")" "$(val)"
		done
	done
done

# negation et double negation
for f in '0!' '1!' '0!!' '1!!' '1!!!' '10&!' '10|!'; do
	run ./ex03/ex03 "$f"
	check "$f" "$(bool_word "$(ref_eval "$f" "" "")")" "$(val)"
done

# exemples du sujet et formules imbriquees
for f in '10&' '10|' '11>' '10=' '1011||=' '1011||&' '0111&&|' '110&|' '101|&' \
         '1101||&' '10^1^' '111&&' '000||' '10>0>' '11=1=' ; do
	run ./ex03/ex03 "$f"
	check "$f" "$(bool_word "$(ref_eval "$f" "" "")")" "$(val)"
done

# constantes seules
run ./ex03/ex03 '1'; check "1" "true" "$(val)"
run ./ex03/ex03 '0'; check "0" "false" "$(val)"

# fuzz : formules constantes aleatoires, attendu calcule par l'oracle
RANDOM=4242
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
	rand_formula "01" 12; f="$FORMULA"
	run ./ex03/ex03 "$f"
	check "fuzz $f" "$(bool_word "$(ref_eval "$f" "" "")")" "$(val)"
done

# erreurs de parsing
run ./ex03/ex03 ''
check "formule vide" "Invalid expression" "$(val)"
check_rc "formule vide" 1 "$RC"

run ./ex03/ex03 '&'
check "operateur seul" "Invalid expression" "$(val)"

run ./ex03/ex03 '1&'
check "operande manquant" "Invalid expression" "$(val)"

run ./ex03/ex03 '!'
check "negation sans operande" "Invalid expression" "$(val)"

run ./ex03/ex03 '11'
check "deux operandes sans operateur" "Invalid expression" "$(val)"

run ./ex03/ex03 '1@'
check "caractere inconnu" "Invalid character in expression" "$(val)"
check_rc "caractere inconnu" 1 "$RC"

run ./ex03/ex03 '1 0&'
check "espace interdit" "Invalid character in expression" "$(val)"

run ./ex03/ex03 '10&&'
check "operateur en trop" "Invalid expression" "$(val)"

# une variable n'a pas de valeur dans eval_formula
run ./ex03/ex03 'AB&'
check_rc "variable non affectee" 1 "$RC"

run ./ex03/ex03
check_rc "sans argument" 1 "$RC"
run ./ex03/ex03 '1' '0'
check_rc "deux arguments" 1 "$RC"

# ================================================== ex04 : print_truth_table

section "ex04 truth table"

# la table complete est comparee a celle de l'oracle, ligne par ligne
for f in 'A' 'A!' 'AB&' 'AB|' 'AB^' 'AB>' 'AB=' 'AB&!' 'AB|!' \
         'AB&C|' 'AB|C&' 'ABC&&' 'ABC||' 'ABC^^' 'AB>C>' 'AB=C=' \
         'ABCD&&&' 'ABCD|||' 'AA&' 'AA^' 'AA!&' 'AZ&' 'AC|' '10&' '1' 'A0&' 'A1|'; do
	run ./ex04/ex04 "$f"
	check "table de $f" "$(ref_table "$f")" "$OUT"
done

# fuzz sur 2 puis 3 variables
RANDOM=777
for i in 1 2 3 4 5 6 7 8 9 10; do
	rand_formula "AB" 9; f="$FORMULA"
	run ./ex04/ex04 "$f"
	check "fuzz table de $f" "$(ref_table "$f")" "$OUT"
done
for i in 1 2 3 4 5 6 7 8; do
	rand_formula "ABC" 11; f="$FORMULA"
	run ./ex04/ex04 "$f"
	check "fuzz table de $f" "$(ref_table "$f")" "$OUT"
done

# en-tete : une colonne par variable + la colonne resultat
run ./ex04/ex04 'ABC&&'
check "en-tete 3 variables" "| A | B | C | = |" "$(printf '%s' "$OUT" | sed -n '1p')"
check "separateur 3 variables" "|---|---|---|---|" "$(printf '%s' "$OUT" | sed -n '2p')"
check "nombre de lignes 3 variables" 10 "$(printf '%s\n' "$OUT" | grep -c '')"

# formule sans variable : une seule ligne de resultat
run ./ex04/ex04 '10|'
check "table sans variable" "$(printf '| = |\n|---|\n| 1 |')" "$OUT"

run ./ex04/ex04 '1@'
check_rc "formule invalide" 1 "$RC"
run ./ex04/ex04
check_rc "sans argument" 1 "$RC"

# ======================================== ex05 : negation normal form (NNF)

section "ex05 NNF"

NNF_CASES='AB& AB| AB> AB= AB^ AB&! AB|! AB>! AB=! AB^! A! A!! A!!! A
AB|C&! AB&C|! AB>C> ABC^^ AB=C= ABCD&&&! ABCD|||! AB&CD&| AB&CD&&!
AB!& A!B| AB^C^! AB>C&!'

for f in $NNF_CASES; do
	run ./ex05/ex05 "$f"
	nnf="$(val)"

	# 1. la forme est bien une NNF (plus de ^ > =, ! seulement sur des atomes)
	check "$f : forme NNF" "nnf" "$(nnf_shape "$nnf")"

	# 2. equivalence logique avec la formule d'origine (via l'oracle)
	check "$f : equivalence -> $nnf" "$(ref_table "$f")" "$(ref_table "$nnf")"

	# 3. idempotence : nnf(nnf(f)) == nnf(f)
	run ./ex05/ex05 "$nnf"
	check "$f : idempotence" "$nnf" "$(val)"
done

# resultats attendus explicites (exemples du sujet)
check_nnf()
{
	run ./ex05/ex05 "$1"
	check "nnf($1)" "$2" "$(val)"
}
check_nnf 'AB&'  'AB&'
check_nnf 'AB|'  'AB|'
check_nnf 'AB>'  'A!B|'
check_nnf 'AB&!' 'A!B!|'
check_nnf 'AB|!' 'A!B!&'
check_nnf 'A!!'  'A'
check_nnf 'A!!!' 'A!'
check_nnf 'A'    'A'

# fuzz : la NNF doit toujours etre bien formee et equivalente
RANDOM=555
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	rand_formula "AB" 10; f="$FORMULA"
	run ./ex05/ex05 "$f"
	nnf="$(val)"
	if [ "${#nnf}" -le "$ORACLE_MAX" ]; then
		check "fuzz $f : forme NNF" "nnf" "$(nnf_shape "$nnf")"
		check "fuzz $f : equivalence" "$(ref_table "$f")" "$(ref_table "$nnf")"
	else
		check "fuzz $f : nnf de ${#nnf} car. sans operateur interdit" "" \
			"$(printf '%s' "$nnf" | tr -d 'A-Z01!&|')"
	fi
done

run ./ex05/ex05 '1@'
check_rc "formule invalide" 1 "$RC"
run ./ex05/ex05
check_rc "sans argument" 1 "$RC"

# ==================================== ex06 : conjunctive normal form (CNF)

section "ex06 CNF"

CNF_CASES='AB& AB| AB&! AB|! AB> AB= AB^ AB&C| AB|C& ABC&& ABC|| ABCD&&& ABCD|||
AB&CD&| AB|CD|& AB&!C!| AB|!C!& AB>C> A B! AA| AB&AB&| ABC&|'

for f in $CNF_CASES; do
	run ./ex06/ex06 "$f"
	cnf="$(val)"

	# 1. la forme est bien une CNF (conjonction de disjonctions de litteraux)
	check "$f : forme CNF" "cnf" "$(cnf_shape "$cnf")"

	# 2. equivalence logique avec la formule d'origine
	check "$f : equivalence -> $cnf" "$(ref_table "$f")" "$(ref_table "$cnf")"

	# 3. idempotence
	run ./ex06/ex06 "$cnf"
	check "$f : idempotence" "$cnf" "$(val)"
done

check_cnf()
{
	run ./ex06/ex06 "$1"
	check "cnf($1)" "$2" "$(val)"
}
check_cnf 'AB&!'    'A!B!|'
check_cnf 'AB|!'    'A!B!&'
check_cnf 'AB|C&'   'AB|C&'
check_cnf 'AB&C|'   'AC|BC|&'
check_cnf 'ABCD&&&' 'ABCD&&&'
check_cnf 'ABCD|||' 'ABCD|||'

# une CNF est aussi une NNF
for f in 'AB&C|' 'AB=' 'AB^' 'ABC&|'; do
	run ./ex06/ex06 "$f"
	check "cnf($f) est une NNF" "nnf" "$(nnf_shape "$(val)")"
done

RANDOM=8888
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
	rand_formula "AB" 9; f="$FORMULA"
	run ./ex06/ex06 "$f"
	cnf="$(val)"
	if [ "${#cnf}" -le "$ORACLE_MAX" ]; then
		check "fuzz $f : forme CNF" "cnf" "$(cnf_shape "$cnf")"
		check "fuzz $f : equivalence" "$(ref_table "$f")" "$(ref_table "$cnf")"
	else
		check "fuzz $f : cnf de ${#cnf} car. sans operateur interdit" "" \
			"$(printf '%s' "$cnf" | tr -d 'A-Z01!&|')"
	fi
done

run ./ex06/ex06 '1@'
check_rc "formule invalide" 1 "$RC"
run ./ex06/ex06
check_rc "sans argument" 1 "$RC"

# ================================================================ ex07 : sat

section "ex07 sat"

# cas connus
check_sat()
{
	run ./ex07/ex07 "$1"
	check "sat($1)" "$2" "$(val)"
}
check_sat 'A'      'true'
check_sat 'A!'     'true'
check_sat 'AB|'    'true'
check_sat 'AB&'    'true'
check_sat 'AA!&'   'false'
check_sat 'AA!|'   'true'
check_sat 'AA^'    'false'
check_sat 'AA='    'true'
check_sat 'AB^'    'true'
check_sat 'ABC&&'  'true'
check_sat 'ABC||'  'true'
check_sat '1'      'true'
check_sat '0'      'false'
check_sat '10&'    'false'
check_sat '10|'    'true'
check_sat 'AA&A!&' 'false'
check_sat 'AB&A!&' 'false'
check_sat 'AB=AB^&' 'false'

# recoupement avec l'oracle : sat(f) <=> la table contient au moins un 1
for f in 'A' 'AB&' 'AB|' 'AB^' 'AB>' 'AB=' 'AA!&' 'AA!|' 'AB&A!&' 'AB=AB^&' \
         'ABC&&' 'AB&C|' 'AB|C&' 'ABC^^' 'AB>C>' 'AA^' 'AB^AB=&' 'ABCD&&&'; do
	run ./ex07/ex07 "$f"
	check "sat($f) == oracle" "$(ref_sat "$f")" "$(val)"
done

RANDOM=31337
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
	rand_formula "ABC" 11; f="$FORMULA"
	run ./ex07/ex07 "$f"
	check "fuzz sat($f)" "$(ref_sat "$f")" "$(val)"
done

run ./ex07/ex07 '1@'
check_rc "formule invalide" 1 "$RC"
run ./ex07/ex07
check_rc "sans argument" 1 "$RC"

# ========================================================== ex08 : powerset

section "ex08 powerset"

check_pset()
{
	local expected="$1"; shift
	run ./ex08/ex08 "$@"
	check "powerset($*)" "$expected" "$(lastline)"
}
check_pset '{ {} }'
check_pset '{ {}, {1} }' 1
check_pset '{ {}, {1}, {2}, {1, 2} }' 1 2
check_pset '{ {}, {1}, {2}, {1, 2}, {3}, {1, 3}, {2, 3}, {1, 2, 3} }' 1 2 3
check_pset '{ {}, {7} }' 7
check_pset '{ {}, {-1}, {-2}, {-1, -2} }' -1 -2
check_pset '{ {}, {0} }' 0
check_pset '{ {}, {5}, {5}, {5, 5} }' 5 5
check_pset '{ {}, {10}, {20}, {10, 20}, {30}, {10, 30}, {20, 30}, {10, 20, 30} }' 10 20 30

# cardinalite : 2^n sous-ensembles
count_subsets()
{
	run ./ex08/ex08 "$@"
	printf '%s' "$(lastline)" | tr -cd '{' | wc -c | tr -d ' '
}
check "cardinalite n=0" 2 "$(count_subsets)"
check "cardinalite n=1" 3 "$(count_subsets 1)"
check "cardinalite n=2" 5 "$(count_subsets 1 2)"
check "cardinalite n=3" 9 "$(count_subsets 1 2 3)"
check "cardinalite n=4" 17 "$(count_subsets 1 2 3 4)"
check "cardinalite n=5" 33 "$(count_subsets 1 2 3 4 5)"
check "cardinalite n=6" 65 "$(count_subsets 1 2 3 4 5 6)"
# (n+1 accolades ouvrantes : 1 pour l'ensemble englobant + 2^n sous-ensembles)

# l'ensemble vide et l'ensemble complet sont toujours presents
run ./ex08/ex08 4 5 6
case "$(lastline)" in
	'{ {},'*) check "contient l'ensemble vide" "oui" "oui" ;;
	*)        check "contient l'ensemble vide" "oui" "non" ;;
esac
case "$(lastline)" in
	*'{4, 5, 6} }') check "contient l'ensemble complet" "oui" "oui" ;;
	*)              check "contient l'ensemble complet" "oui" "non" ;;
esac

# elements invalides
run ./ex08/ex08 1 x
check "element non numerique" "invalid element: x" "$(val)"
check_rc "element non numerique" 1 "$RC"
run ./ex08/ex08 12abc
check "element partiellement numerique" "invalid element: 12abc" "$(val)"
run ./ex08/ex08 1 2.5
check "element decimal" "invalid element: 2.5" "$(val)"
run ./ex08/ex08 1 2 3
check_rc "elements valides" 0 "$RC"

# ========================================================== ex09 : eval_set

section "ex09 eval_set"

check_set()
{
	local expected="$1"; shift
	run ./ex09/ex09 "$@"
	check "eval_set $*" "$expected" "$(lastline)"
}

# identite, union, intersection, complement
check_set '[1, 7, 42]'       'A'     42 1 7
check_set '[1, 2, 3]'        'A'     3 1 2
check_set '[1, 2]'           'A'     1 1 2
check_set '[-5, 3]'          'A'     -5 3
check_set '[]'               'A!'    0 1 2
check_set '[2, 3]'           'AB&'   1 2 3 ';' 2 3 4
check_set '[1, 2, 3, 4, 5]'  'AB|'   1 2 3 ';' 3 4 5
check_set '[1, 4]'           'AB&!'  1 2 3 ';' 2 3 4
check_set '[]'               'AB|!'  1 2 3 ';' 2 3 4
check_set '[3]'              'A!B&'  1 2 ';' 2 3

# les operateurs >, = et ^ passent par la NNF
check_set '[3, 4, 5]'        'AB>'   1 2 3 ';' 3 4 5
check_set '[3]'              'AB='   1 2 3 ';' 3 4 5
check_set '[1, 2, 4, 5]'     'AB^'   1 2 3 ';' 3 4 5

# trois ensembles
check_set '[2, 7]'           'AB&C|' 1 2 ';' 2 3 ';' 7

# idempotence / tautologie / contradiction sur l'univers
check_set '[1, 2]'           'AA&'   1 2
check_set '[1, 2]'           'AA|'   1 2
check_set '[]'               'AA!&'  1 2
check_set '[1, 2]'           'AA!|'  1 2

# ensemble vide en premiere position
check_set '[]'               'A'     ';' 1 2
check_set '[1, 2]'           'B'     ';' 1 2
check_set '[1, 2]'           'AB|'   ';' 1 2

# l'univers est l'union de tous les ensembles fournis
check_set '[4]'              'A!'    1 2 3 ';' 4

# erreurs
run ./ex09/ex09 'AB&' 1 2
check "pas assez d'ensembles" "Not enough sets for the formula" "$(val)"
check_rc "pas assez d'ensembles" 1 "$RC"

run ./ex09/ex09 'AB' 1 ';' 2
check "formule mal formee" "Invalid expression" "$(val)"

run ./ex09/ex09 'A@' 1
check "caractere inconnu" "Invalid character in expression" "$(val)"

# une constante n'a pas de sens sur des ensembles : refus explicite, pas de crash
OPERAND_ERR="Operands are not allowed, run NNF first"
run ./ex09/ex09 '1' 1 2
check "constante 1 refusee" "$OPERAND_ERR" "$(val)"
check_rc "constante 1 refusee" 1 "$RC"
run ./ex09/ex09 '0' 1 2
check "constante 0 refusee" "$OPERAND_ERR" "$(val)"
run ./ex09/ex09 '1A&' 1 2
check "constante en operande gauche refusee" "$OPERAND_ERR" "$(val)"
run ./ex09/ex09 'A1|' 1 2
check "constante en operande droit refusee" "$OPERAND_ERR" "$(val)"
run ./ex09/ex09 'A0&!' 1 2
check "constante sous une negation refusee" "$OPERAND_ERR" "$(val)"

run ./ex09/ex09
check_rc "sans argument" 1 "$RC"

run ./ex09/ex09 'A' 1 2
check_rc "appel valide" 0 "$RC"

# =============================================================== ex10 : map

section "ex10 map"

check_map()
{
	run ./ex10/ex10 "$1" "$2"
	check "map($1, $2)" "$(awk_map "$1" "$2")" "$(val)"
}
check_map 0 0
check_map 1 0
check_map 0 1
check_map 1 1
check_map 5 3
check_map 255 0
check_map 0 255
check_map 255 255
check_map 256 256
check_map 1024 2048
check_map 32768 32768
check_map 43690 21845
check_map 65535 0
check_map 0 65535
check_map 65535 65535
check_map 12345 54321

# bornes connues
run ./ex10/ex10 0 0
check "map(0,0) == 0" "0" "$(val)"
run ./ex10/ex10 65535 65535
check "map(65535,65535) == 1" "1" "$(val)"

# le resultat reste dans [0, 1]
in_unit()
{
	run ./ex10/ex10 "$1" "$2"
	awk -v v="$(val)" 'BEGIN { if (v >= 0 && v <= 1) print "ok"; else print "hors [0,1]" }'
}
for p in '0 0' '1 0' '0 1' '65535 65535' '65535 0' '0 65535' '12345 54321' '32768 1'; do
	set -- $p
	check "map($1, $2) dans [0,1]" "ok" "$(in_unit "$1" "$2")"
done

# injectivite sur un echantillon
SEEN=""
DUP=0
for p in '0 0' '0 1' '1 0' '1 1' '2 0' '0 2' '5 3' '3 5' '255 0' '0 255' \
         '256 1' '1 256' '65535 0' '0 65535' '65535 65535' '12345 54321'; do
	set -- $p
	run ./ex10/ex10 "$1" "$2"
	m="$(val)"
	case " $SEEN " in
		*" $m "*) DUP=$((DUP + 1)) ;;
	esac
	SEEN="$SEEN $m"
done
check "injectivite sur 16 couples" 0 "$DUP"

RANDOM=99
for i in 1 2 3 4 5 6 7 8 9 10; do
	x=$((RANDOM % 65536))
	y=$((RANDOM % 65536))
	run ./ex10/ex10 "$x" "$y"
	check "fuzz map($x, $y)" "$(awk_map "$x" "$y")" "$(val)"
done

run ./ex10/ex10
check_rc "sans argument" 1 "$RC"
run ./ex10/ex10 1
check_rc "un seul argument" 1 "$RC"
run ./ex10/ex10 1 2 3
check_rc "trois arguments" 1 "$RC"

# ======================================================= ex11 : reverse_map

section "ex11 reverse_map"

# on alimente ex11 avec la valeur exacte calculee par l'oracle awk : le
# de-entrelacement est donc teste independamment de l'affichage de ex10.
check_rev()
{
	run ./ex11/ex11 "$(awk_map "$1" "$2")"
	check "reverse_map(map($1, $2))" "($1, $2)" "$(val)"
}
check_rev 0 0
check_rev 1 0
check_rev 0 1
check_rev 1 1
check_rev 5 3
check_rev 255 0
check_rev 0 255
check_rev 255 255
check_rev 256 256
check_rev 1024 2048
check_rev 32768 32768
check_rev 43690 21845
check_rev 65535 0
check_rev 0 65535
check_rev 65535 65535
check_rev 12345 54321

# bornes
run ./ex11/ex11 0
check "reverse_map(0)" "(0, 0)" "$(val)"
run ./ex11/ex11 1
check "reverse_map(1)" "(65535, 65535)" "$(val)"

# les bits pairs vont a x, les bits impairs a y
run ./ex11/ex11 "$(awk -v m=$MAXU32 'BEGIN { printf "%.17g", 1 / m }')"
check "bit 0 -> x" "(1, 0)" "$(val)"
run ./ex11/ex11 "$(awk -v m=$MAXU32 'BEGIN { printf "%.17g", 2 / m }')"
check "bit 1 -> y" "(0, 1)" "$(val)"
run ./ex11/ex11 "$(awk -v m=$MAXU32 'BEGIN { printf "%.17g", 3 / m }')"
check "bits 0 et 1 -> x et y" "(1, 1)" "$(val)"

RANDOM=1234
for i in 1 2 3 4 5 6 7 8 9 10; do
	x=$((RANDOM % 65536))
	y=$((RANDOM % 65536))
	run ./ex11/ex11 "$(awk_map "$x" "$y")"
	check "fuzz reverse_map(map($x, $y))" "($x, $y)" "$(val)"
done

run ./ex11/ex11
check_rc "sans argument" 1 "$RC"
run ./ex11/ex11 0.5 0.5
check_rc "deux arguments" 1 "$RC"

# ============================================ ex10 <-> ex11 : aller-retour

section "ex10<->ex11 aller-retour"

# ici on repasse vraiment par la sortie texte de ex10
roundtrip()
{
	run ./ex10/ex10 "$1" "$2"
	local m
	m="$(val)"
	run ./ex11/ex11 "$m"
	check "($1, $2) -> $m -> retour" "($1, $2)" "$(val)"
}
roundtrip 0 0
roundtrip 1 0
roundtrip 0 1
roundtrip 1 1
roundtrip 5 3
roundtrip 255 0
roundtrip 0 255
roundtrip 256 256
roundtrip 1000 1000
roundtrip 32768 32768
roundtrip 43690 21845
roundtrip 65535 0
roundtrip 0 65535
roundtrip 65535 65535
roundtrip 65534 65535
roundtrip 12345 54321

RANDOM=5150
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
	roundtrip "$((RANDOM % 65536))" "$((RANDOM % 65536))"
done

# tous les bits de poids fort et faible
for b in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768; do
	roundtrip "$b" 0
	roundtrip 0 "$b"
done

section_end

# ================================================== robustesse (aucun crash)

section "robustesse"

# aucun binaire ne doit se terminer sur un signal (segfault, abort...),
# quelle que soit la saloperie qu'on lui passe.
no_crash()
{
	local name="$1"
	shift
	$TIMEOUT "$@" >/dev/null 2>&1
	local rc=$?

	if [ "$rc" -ge 128 ]; then
		check "$name" "sortie propre" "signal $((rc - 128))"
	elif [ "$rc" -eq 124 ]; then
		check "$name" "sortie propre" "timeout"
	else
		check "$name" "sortie propre" "sortie propre"
	fi
}

# formules mal formees sur tous les exercices qui parsent du RPN
for e in ex03 ex04 ex05 ex06 ex07; do
	for f in '' '!' '&' '|' '^' '>' '=' '1' '11' '1&' 'A&' 'AB' '1@' 'A!!!!!!' \
	         '@' ' ' 'a' 'AB&&&' '!!!' '0!!!!!!!!' 'A!B!&!C!|!'; do
		no_crash "$e sur [$f]" "./$e/$e" "$f"
	done
done

# beaucoup de variables : ex04 et ex07 enumerent 2^n lignes, on reste a 8
# variables (256 lignes) ; ex03/ex05/ex06 ne developpent pas de table et
# peuvent encaisser les 26 lettres.
for e in ex04 ex07; do
	no_crash "$e 8 variables" "./$e/$e" 'ABCDEFGH&&&&&&&'
done
for e in ex03 ex05 ex06; do
	no_crash "$e 26 variables" "./$e/$e" 'ABCDEFGHIJKLMNOPQRSTUVWXYZ&&&&&&&&&&&&&&&&&&&&&&&&&'
done

# ex09 : formules et ensembles limites
for f in '' '!' '&' 'A' 'AB' 'AB&' '1' '0' '1A&' 'Z' 'A@' 'AZ&'; do
	no_crash "ex09 sur [$f]" ./ex09/ex09 "$f" 1 2
done
no_crash "ex09 sans ensemble" ./ex09/ex09 'A'
no_crash "ex09 ensembles vides" ./ex09/ex09 'AB|' ';'
no_crash "ex09 separateurs consecutifs" ./ex09/ex09 'AB|' ';' ';' ';'
no_crash "ex09 element non numerique" ./ex09/ex09 'A' abc

# entiers hors bornes / negatifs
for e in ex00 ex01; do
	no_crash "$e valeurs enormes" "./$e/$e" 99999999999999999999 99999999999999999999
	no_crash "$e valeurs negatives" "./$e/$e" -1 -1
	no_crash "$e non numerique" "./$e/$e" abc def
done
no_crash "ex02 valeur enorme" ./ex02/ex02 99999999999999999999
no_crash "ex02 valeur negative" ./ex02/ex02 -1
no_crash "ex08 beaucoup d'elements" ./ex08/ex08 1 2 3 4 5 6 7 8 9 10 11 12
no_crash "ex08 element enorme" ./ex08/ex08 99999999999999999999
no_crash "ex10 hors bornes" ./ex10/ex10 99999 99999
no_crash "ex10 negatif" ./ex10/ex10 -1 -1
no_crash "ex10 non numerique" ./ex10/ex10 abc def
no_crash "ex11 hors de [0,1]" ./ex11/ex11 2
no_crash "ex11 negatif" ./ex11/ex11 -1
no_crash "ex11 non numerique" ./ex11/ex11 abc
no_crash "ex11 infini" ./ex11/ex11 inf
no_crash "ex11 nan" ./ex11/ex11 nan

section_end

# ============================================ ex06 : cout de la distribution

section "ex06 complexite"

# La mise en CNF par distribution duplique ses sous-arbres a chaque '=' et
# chaque '^' : la sortie grossit exponentiellement avec l'imbrication. Ce
# n'est pas un bug (c'est le comportement de l'algorithme), mais il faut
# savoir ou est le mur. On fige donc les tailles attendues.
cnf_len()
{
	local v
	run ./ex06/ex06 "$1"
	v="$(val)"
	printf '%s' "${#v}"
}

# formules "plates" : la CNF reste de la taille de l'entree
check "|cnf(AB&C|)|"   7    "$(cnf_len 'AB&C|')"
check "|cnf(ABCD&&&)|" 7    "$(cnf_len 'ABCD&&&')"
check "|cnf(AB|C&)|"   5    "$(cnf_len 'AB|C&')"

# chaines de '=' : x7 environ a chaque niveau
check "|cnf(AB=)|"     19   "$(cnf_len 'AB=')"
check "|cnf(AB=C=)|"   130  "$(cnf_len 'AB=C=')"
check "|cnf(AB=C=D=)|" 1682 "$(cnf_len 'AB=C=D=')"

# chaines de '^' : meme ordre de grandeur
check "|cnf(AB^)|"     19   "$(cnf_len 'AB^')"
check "|cnf(AB^C^)|"   128  "$(cnf_len 'AB^C^')"
check "|cnf(AB^C^D^)|" 1691 "$(cnf_len 'AB^C^D^')"

# malgre l'explosion de taille, le resultat reste juste et bien forme
for f in 'AB=C=' 'AB^C^' 'AB=C=D=' 'AB^C^D^'; do
	run ./ex06/ex06 "$f"
	cnf="$(val)"
	check "$f : forme CNF malgre l'explosion" "cnf" "$(cnf_shape "$cnf")"
	check "$f : equivalence malgre l'explosion" "$(ref_table "$f")" "$(ref_table "$cnf")"
done

# Un niveau de plus depasse deja les 60 000 caracteres. On ne lui applique
# pas cnf_shape() : le parseur bash est quadratique (${str:i:1} est O(i)) et
# mettrait ~25 s. On se contente d'un controle bon marche : ca termine, la
# taille est bien dans l'ordre de grandeur attendu, et il ne reste aucun
# operateur interdit en CNF.
run ./ex06/ex06 'AB=C=D=E='
check_rc "AB=C=D=E= termine" 0 "$RC"
cnf="$(val)"
check "AB=C=D=E= depasse 60000 caracteres" "oui" \
	"$(if [ "${#cnf}" -gt 60000 ]; then printf 'oui'; else printf 'non (%s)' "${#cnf}"; fi)"
check "AB=C=D=E= sans operateur interdit" "" \
	"$(printf '%s' "$cnf" | tr -d 'A-Z01!&|')"

section_end

# ==================================================== audit memoire (--leaks)

if [ -n "$LEAKS" ]; then
	MEMTOOL=""
	case "$(uname)" in
		Darwin)
			command -v leaks >/dev/null 2>&1 && MEMTOOL="leaks"
			;;
		Linux)
			command -v valgrind >/dev/null 2>&1 && MEMTOOL="valgrind"
			;;
	esac

	if [ -z "$MEMTOOL" ]; then
		printf '  %s! audit memoire ignore : ni leaks ni valgrind disponible%s\n' \
			"$YELLOW" "$RESET"
	else
		section "memoire ($MEMTOOL)"

		# no_leak <nom> <cmd...> : 0 fuite attendue
		no_leak()
		{
			local name="$1"
			shift
			local out got

			if [ "$MEMTOOL" = "leaks" ]; then
				out="$(MallocStackLogging=1 $TIMEOUT leaks --atExit -- "$@" 2>&1)"
				case "$out" in
					*"0 leaks for 0 total leaked bytes"*)
						got="0 octet" ;;
					*)
						# on remonte le nombre d'octets pour un diagnostic utile
						got="$(printf '%s' "$out" \
							| sed -n 's/.*: \([0-9][0-9]*\) leaks* for \([0-9][0-9]*\) total leaked bytes.*/\1 fuite(s), \2 octets/p' \
							| tail -1)"
						[ -n "$got" ] || got="sortie de leaks illisible" ;;
				esac
			else
				out="$($TIMEOUT valgrind --leak-check=full --show-leak-kinds=definite \
					--errors-for-leak-kinds=definite --error-exitcode=42 -q "$@" 2>&1 >/dev/null)"
				if [ -z "$out" ]; then
					got="0 octet"
				else
					got="$(printf '%s' "$out" \
						| sed -n 's/.*definitely lost: \([0-9,]*\) bytes in \([0-9,]*\) blocks.*/\2 fuite(s), \1 octets/p' \
						| tail -1)"
					[ -n "$got" ] || got="erreurs valgrind"
				fi
			fi
			check "$name" "0 octet" "$got"
		}

		# --- chemins nominaux
		no_leak "ex00 nominal" ./ex00/ex00 3 5
		no_leak "ex01 nominal" ./ex01/ex01 3 5
		no_leak "ex02 nominal" ./ex02/ex02 7
		no_leak "ex03 nominal" ./ex03/ex03 '1011||='
		no_leak "ex04 nominal" ./ex04/ex04 'AB&C|'
		no_leak "ex05 nominal" ./ex05/ex05 'AB|C&!'
		no_leak "ex06 nominal" ./ex06/ex06 'AB&C|'
		no_leak "ex07 nominal" ./ex07/ex07 'AB&C|'
		no_leak "ex08 nominal" ./ex08/ex08 1 2 3
		no_leak "ex09 nominal" ./ex09/ex09 'AB&' 1 2 3 ';' 2 3 4
		no_leak "ex10 nominal" ./ex10/ex10 5 3
		no_leak "ex11 nominal" ./ex11/ex11 0.5

		# --- doubles negations : pushNegation() remplace le noeud '!' externe
		no_leak "ex05 double negation A!!"   ./ex05/ex05 'A!!'
		no_leak "ex05 double negation A!!!!" ./ex05/ex05 'A!!!!'
		no_leak "ex05 double negation AB&!!" ./ex05/ex05 'AB&!!'
		no_leak "ex05 double negation AB>!"  ./ex05/ex05 'AB>!'
		no_leak "ex05 double negation AB=C=" ./ex05/ex05 'AB=C='
		no_leak "ex06 double negation A!!"   ./ex06/ex06 'A!!'
		no_leak "ex06 double negation AB=C=" ./ex06/ex06 'AB=C='
		no_leak "ex09 double negation"       ./ex09/ex09 'AB&!!' 1 2 ';' 2 3

		# --- chemins d'erreur : l'arbre deja construit doit etre libere
		no_leak "ex03 erreur de parsing"      ./ex03/ex03 '1@'
		no_leak "ex03 pile non vidangee"      ./ex03/ex03 '11'
		no_leak "ex03 variable non affectee"  ./ex03/ex03 'AB&'
		no_leak "ex04 erreur de parsing"      ./ex04/ex04 '1@'
		no_leak "ex05 erreur de parsing"      ./ex05/ex05 '1@'
		no_leak "ex06 erreur de parsing"      ./ex06/ex06 '1@'
		no_leak "ex07 erreur de parsing"      ./ex07/ex07 '1@'
		no_leak "ex09 erreur de parsing"      ./ex09/ex09 '1@' 1
		no_leak "ex09 pas assez d'ensembles"  ./ex09/ex09 'AB&' 1 2
		no_leak "ex09 constante refusee"      ./ex09/ex09 '1' 1 2

		section_end
	fi
fi

# ================================================================== resume

printf '\n%s' "$BOLD"
printf '────────────────────────────────────────────\n'
printf '%s' "$RESET"
printf '  %sreussis%s : %s\n' "$GREEN" "$RESET" "$PASS"
printf '  %sechoues%s : %s\n' "$RED" "$RESET" "$FAIL"
printf '  total   : %s\n' "$((PASS + FAIL))"
if [ -z "$LEAKS" ]; then
	printf '  %saudit memoire non lance (--leaks pour l activer)%s\n' "$GRAY" "$RESET"
fi
printf '\n'

[ "$FAIL" -eq 0 ]
