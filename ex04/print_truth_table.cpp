#include "colors.hpp"
#include "ast.hpp"
#include <iostream>
#include <vector>

// Extrait les variables uniques d'une formule booléenne
std::vector<char>	extractVariables(const std::string &formula)
{
	std::vector<char>	variables;

	for (char c = 'A'; c <= 'Z'; c++)
	{
		if (formula.find(c) != std::string::npos)
			variables.push_back(c);
	}

	return (variables);
}

// Affiche l'en-tête de la table de vérité avec les variables et le résultat
void	printHeader(const std::vector<char> &variables)
{
	for (char v : variables)
		std::cout << "| " << v << " ";

	std::cout << "| = |" << std::endl;

	for (std::size_t i = 0; i < variables.size() + 1; i++)
		std::cout << "|---";

	std::cout << "|" << std::endl;
}

// Affiche une ligne de la table de vérité avec les valeurs des variables et le résultat
void	printRow(const std::vector<char> &variables, unsigned int combination, bool result)
{
	std::size_t	count = variables.size();

	for (std::size_t k = 0; k < count; k++)
		std::cout << "| " << ((combination >> (count - k - 1)) & 1) << " ";

	std::cout << "| " << result << " |" << std::endl;
}

// Affiche la table de vérité complète pour une formule booléenne
void	printTruthTable(const std::string &formula)
{
	Node				*root = buildTree(formula);
	std::vector<char>	variables = extractVariables(formula);
	unsigned int		rows = 1 << variables.size();

	printHeader(variables);

	for (unsigned int i = 0; i < rows; i++)
	{
		std::map<char, bool>	values;
		std::size_t				count = variables.size();

		for (std::size_t k = 0; k < count; k++)
			values[variables[k]] = (i >> (count - k - 1)) & 1;

		printRow(variables, i, evalNodeVars(root, values));
	}

	delete root;
}

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(4, argv[0] << " <formula>") << std::endl;
		return (1);
	}

	try
	{
		std::string	formula = argv[1];
		printTruthTable(formula);

		return (0);
	}
	catch (const std::exception &e)
	{
		std::cerr << ERROR(4, e.what()) << std::endl;
		return (1);
	}
}