#include "colors.hpp"
#include "ast.hpp"
#include <iostream>
#include <set>

// Construit l'univers des éléments à partir d'un ensemble de sous-ensembles.
std::set<int>	buildUniverse(const std::vector<std::vector<int> > &sets)
{
	std::set<int>	universe;

	for (const std::vector<int> &s : sets)
	{
		for (int value : s)
			universe.insert(value);
	}
	return (universe);
}

// Évalue un nœud de l'arbre syntaxique pour un ensemble de sous-ensembles d'entiers.
std::set<int>	evalNodeSet(Node *node, const std::vector<std::vector<int> > &sets, const std::set<int> &universe)
{
	if (isOperand(node->symbol))
		throw std::invalid_argument("Operands are not allowed, run NNF first");
	if (isVariable(node->symbol))
	{
		std::size_t		index = node->symbol - 'A';

		if (index >= sets.size())
			throw std::invalid_argument("Not enough sets for the formula");
		return (std::set<int>(sets[index].begin(), sets[index].end()));
	}

	if (isUnary(node->symbol))
	{
		std::set<int>	child = evalNodeSet(node->left, sets, universe);
		std::set<int>	result;

		for (int value : universe)
		{
			if (child.count(value) == 0)
				result.insert(value);
		}
		return (result);
	}

	std::set<int>	left = evalNodeSet(node->left, sets, universe);
	std::set<int>	right = evalNodeSet(node->right, sets, universe);
	std::set<int>	result;

	if (node->symbol == '&')
	{
		for (int value : left)
		{
			if (right.count(value) != 0)
				result.insert(value);
		}
	}
	else if (node->symbol == '|')
	{
		result = left;
		for (int value : right)
			result.insert(value);
	}
	else
		throw std::invalid_argument("Operator not allowed, run NNF first");
	return (result);
}

// Évalue une formule booléenne sur un ensemble de sous-ensembles d'entiers.
std::vector<int>	eval_set(const std::string &formula, const std::vector<std::vector<int> > &sets)
{
	std::string		nnf = negationNormalForm(formula);
	Node			*root = buildTree(nnf);
	std::set<int>	universe = buildUniverse(sets);

	try {
		std::set<int>	resultSet = evalNodeSet(root, sets, universe);

		delete root;

		return (std::vector<int>(resultSet.begin(), resultSet.end()));
	} catch (...) {
		delete root;
		throw;
	}
}

// Affiche un ensemble d'entiers sous forme de liste entre crochets.
void	printSet(const std::vector<int> &set)
{
	std::cout << "[";
	for (std::size_t i = 0; i < set.size(); i++)
	{
		std::cout << set[i];
		if (i + 1 < set.size())
			std::cout << ", ";
	}
	std::cout << "]" << std::endl;
}

int	main(int argc, char **argv)
{
	if (argc < 2)
	{
		std::cerr << USAGE(9, argv[0] << " <formula> <set> [; <set> ...]") << std::endl;
		return (1);
	}

	std::string						formula = argv[1];
	std::vector<std::vector<int> >	sets;
	std::vector<int>				current;

	for (int i = 2; i < argc; i++)
	{
		if (std::string(argv[i]) == ";")
		{
			sets.push_back(current);
			current.clear();
		}
		else
			current.push_back(std::strtol(argv[i], nullptr, 10));
	}

	sets.push_back(current);

	try
	{
		printSet(eval_set(formula, sets));

		return (0);
	}
	catch (const std::exception &e)
	{
		std::cerr << ERROR(9, e.what()) << std::endl;
		return (1);
	}
}