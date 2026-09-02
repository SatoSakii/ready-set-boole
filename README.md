# Ready, Set, Boole!

> Introduction à l'algèbre de Boole et à la théorie des ensembles

Une série de douze exercices en C++ qui partent de l'arithmétique bit à bit pour
remonter jusqu'à la logique propositionnelle, les formes normales, un solveur SAT,
et quelques notions de théorie des ensembles. Le fil rouge : comprendre comment,
à partir de simples opérations booléennes, on reconstruit le calcul.

---

## Sommaire

- [Prérequis](#prérequis)
- [Compilation](#compilation)
- [Utilisation](#utilisation)
- [Architecture](#architecture)
- [Les exercices](#les-exercices)
- [Notation des formules](#notation-des-formules)
- [Tests](#tests)

---

## Prérequis

- Un compilateur C++ (`c++` / `clang++` / `g++`)
- `make`
- Optionnel : `valgrind` (pour les tests de fuites mémoire)

---

## Compilation

Tout se compile depuis un unique `Makefile` à la racine.

```sh
make            # compile tous les exercices
make ex00       # compile un seul exercice
make re         # recompile tout depuis zéro
make clean      # supprime les objets
make fclean     # supprime objets + binaires
```

Chaque exercice produit son propre binaire dans son dossier, par exemple
`ex00/ex00`, `ex05/ex05`, etc.

Options de compilation : `-Wall -Werror -Wextra`.

---

## Utilisation

Les formules booléennes sont passées en argument. Attention : certains symboles
(`&`, `|`, `>`, `;`) sont interprétés par le shell - il faut **les mettre entre
guillemets**.

```sh
./ex00/ex00 3 5                       # addition bit à bit      -> 8
./ex01/ex01 3 5                       # multiplication bit à bit -> 15
./ex02/ex02 4                         # code de Gray            -> 6
./ex03/ex03 "10&"                     # évaluation              -> false
./ex04/ex04 "AB&C|"                   # table de vérité
./ex05/ex05 "AB&!"                    # forme normale négative  -> A!B!|
./ex06/ex06 "AB&C|"                   # forme normale conjonctive
./ex07/ex07 "AB|"                     # satisfiabilité          -> true
./ex08/ex08 1 2 3                     # powerset
./ex09/ex09 "AB&" 0 1 2 ";" 0 3 4     # évaluation ensembliste  -> [0]
./ex10/ex10 5 3                       # (x, y) -> [0;1]
./ex11/ex11 6.28643e-09               # [0;1] -> (x, y)         -> (5, 3)
```

---

## Architecture

Le cœur du projet est un **arbre syntaxique abstrait** (AST) partagé, situé dans
`shared/ast.hpp`. Il est réutilisé par tous les exercices
qui manipulent des formules (03 à 09).

```
ready-set-boole/
├── Makefile
├── shared/
│   ├── ast.hpp        # AST : parsing, évaluation, transformations
│   └── colors.hpp     # macros d'affichage
├── ex00/ … ex11/      # un dossier et un binaire par exercice
└── tests/
    └── run_tests.sh   # suite de tests (valeurs + fuites mémoire)
```

Les briques de `ast.hpp`, construites une fois et réemployées partout :

| Fonction | Rôle |
|---|---|
| `buildTree` | parse une formule RPN en arbre |
| `treeToRPN` | sérialise un arbre en formule RPN |
| `evalNodeVars` | évalue un arbre pour une affectation de variables |
| `copyTree` | copie profonde d'un sous-arbre |
| `deleteOperator` | élimine `>`, `=`, `^` (les réécrit en `& \| !`) |
| `pushNegation` | pousse les négations vers les feuilles (De Morgan) |
| `distribute` | distribue les `\|` sur les `&` (pour la CNF) |

---

## Les exercices

### Arithmétique bit à bit

- **ex00 - Adder.** Additionne deux entiers sans l'opérateur `+`, uniquement avec
  des opérations bit à bit. La retenue est calculée par `AND`, la somme sans
  retenue par `XOR`, et l'ensemble est propagé en boucle jusqu'à épuisement de la
  retenue. Complexité *O(log n)*.
- **ex01 - Multiplier.** Multiplie deux entiers en réutilisant l'additionneur
  précédent, par la méthode du paysan russe (décalages et additions).
- **ex02 - Gray code.** Convertit un entier vers son code de Gray par `n ^ (n >> 1)`.

### Logique propositionnelle

- **ex03 - Boolean evaluation.** Évalue une formule propositionnelle en notation
  polonaise inversée et renvoie son résultat.
- **ex04 - Truth table.** Affiche la table de vérité d'une formule à variables.
- **ex05 - Negation Normal Form.** Réécrit une formule sous forme normale négative :
  seuls subsistent `!`, `&`, `|`, et chaque négation est collée à une variable.
- **ex06 - Conjunctive Normal Form.** Pousse la NNF plus loin : une conjonction de
  disjonctions, tous les `&` regroupés en fin de formule.
- **ex07 - SAT.** Détermine si une formule est satisfiable, c'est-à-dire s'il
  existe au moins une affectation de ses variables qui la rend vraie.

### Théorie des ensembles

- **ex08 - Powerset.** Renvoie l'ensemble de tous les sous-ensembles d'un ensemble
  donné (2ⁿ sous-ensembles pour n éléments).
- **ex09 - Set evaluation.** Évalue une formule où les variables sont des ensembles :
  `&` devient l'intersection, `|` l'union, `!` le complément par rapport à l'union
  de tous les ensembles fournis.

### Courbes de remplissage (optionnels)

- **ex10 - Curve.** Encode un couple de coordonnées 16 bits en un unique réel de
  `[0;1]`, par entrelacement des bits (courbe de Lebesgue / Z-order).
- **ex11 - Inverse function.** L'opération inverse : décode un réel de `[0;1]` vers
  son couple de coordonnées. L'aller-retour `reverse_map(map(x, y))` redonne
  exactement `(x, y)`.

---

## Notation des formules

Les formules sont écrites en **notation polonaise inversée** (l'opérateur suit ses
opérandes). Chaque caractère est un symbole :

| Symbole | Signification | Équivalent mathématique |
|:---:|---|:---:|
| `0` | faux | ⊥ |
| `1` | vrai | ⊤ |
| `A`…`Z` | variable | - |
| `!` | négation | ¬ |
| `&` | conjonction | ∧ |
| `\|` | disjonction | ∨ |
| `^` | disjonction exclusive | ⊕ |
| `>` | implication | ⇒ |
| `=` | équivalence | ⇔ |

Exemple : `AB&C|` se lit `(A ∧ B) ∨ C`.

---

## Tests

Une suite de tests vérifie à la fois les **résultats attendus** et l'**absence de
fuites mémoire**.

```sh
make test                    # vérifie les valeurs
make test-leaks    			 # vérifie en plus l'absence de fuites (valgrind OU leaks)
make test-verbose			 # vérifie les valeurs avec plus de détails
```

Pour les exercices produisant plusieurs résultats valides (NNF, CNF), les tests ne
comparent pas la chaîne de sortie caractère par caractère, mais vérifient
l'**équivalence logique** en comparant les tables de vérité de l'entrée et de la
sortie.