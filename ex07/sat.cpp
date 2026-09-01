#include "colors.hpp"
#include "ast.hpp"
#include <iostream>

bool	sat(const std::string &formula)
{
	Node				*root = buildTree(formula);
	std::vector<char>	variables = extractVariables(formula);
	unsigned int		rows = 1 << variables.size();
	std::size_t			count = variables.size();

	for (unsigned int i = 0; i < rows; i++)
	{
		std::map<char, bool>	values;

		for (std::size_t k = 0; k < count; k++)
			values[variables[k]] = (i >> (count - k - 1)) & 1;

		if (evalNodeVars(root, values))
		{
			delete root;

			return (true);
		}
	}

	delete root;

	return (false);
}

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(7, argv[0] << " <formula>") << std::endl;
		return (1);
	}

	try
	{
		std::string	formula = argv[1];
		std::string	result = sat(formula) ? "true" : "false";

		std::cout << RESULT(7, result) << std::endl;
		return (0);
	}
	catch (const std::exception &e)
	{
		std::cerr << ERROR(7, e.what()) << std::endl;
		return (1);
	}
}