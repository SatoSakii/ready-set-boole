#include "colors.hpp"
#include "ast.hpp"
#include <iostream>

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(6, argv[0] << " <formula>") << std::endl;
		return (1);
	}

	try
	{
		std::string	formula = argv[1];
		std::string	result = conjunctiveNormalForm(formula);

		std::cout << RESULT(6, result) << std::endl;

		return (0);
	}
	catch (const std::exception &e)
	{
		std::cerr << ERROR(6, e.what()) << std::endl;
		return (1);
	}
}