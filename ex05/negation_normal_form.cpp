#include "colors.hpp"
#include "ast.hpp"
#include <iostream>

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(5, argv[0] << " <formula>") << std::endl;
		return (1);
	}

	try
	{
		std::string	formula = argv[1];
		std::cout << RESULT(5, negationNormalForm(formula)) << std::endl;

		return (0);
	}
	catch (const std::exception &e)
	{
		std::cerr << ERROR(5, e.what()) << std::endl;
		return (1);
	}
}