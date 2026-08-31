#ifndef COLORS_HPP
# define COLORS_HPP

# define RED     "\033[31m"
# define GREEN   "\033[32m"
# define CYAN    "\033[36m"
# define GRAY    "\033[90m"
# define BOLD    "\033[1m"
# define ITALIC  "\033[3m"
# define RESET   "\033[0m"

# define TAG(n) GRAY ITALIC "[ready-set-boole/ex" << ((n) < 10 ? "0" : "") << (n) << "]" RESET

# define USAGE(n, ...) TAG(n) << " " << RED BOLD "✖ Usage" RESET \
	<< GRAY " → " RESET << __VA_ARGS__

# define RESULT(n, ...) TAG(n) << " " << GREEN BOLD "✔ Result" RESET \
	<< GRAY " → " RESET << __VA_ARGS__

#endif