#include "colors.hpp"
#include "ast.hpp"
#include <iostream>

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(3, argv[0] << " <formula>") << std::endl;
		return (1);
	}

	try
	{
		std::string formula = argv[1];
		std::string result = evalFormula(formula) ? "true" : "false";

		std::cout << RESULT(3, result) << std::endl;

		return (0);
	}
	catch (const std::exception &e)
	{
		std::cerr << ERROR(3, e.what()) << std::endl;
		return (1);
	}

	return (0);
}