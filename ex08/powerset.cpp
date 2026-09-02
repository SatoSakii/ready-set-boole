#include "colors.hpp"
#include <iostream>
#include <vector>

// Génère l'ensemble des sous-ensembles (powerset) d'un ensemble donné.
std::vector<std::vector<int> >	powerset(const std::vector<int> &set)
{
	std::vector<std::vector<int> >	result;
	unsigned int					n = set.size();
	unsigned int					total = 1 << n;

	for (unsigned int i = 0; i < total; i++)
	{
		std::vector<int>	subset;

		for (unsigned int k = 0; k < n; k++)
		{
			if ((i >> k) & 1)
				subset.push_back(set[k]);
		}
		result.push_back(subset);
	}
	return (result);
}

// Affiche l'ensemble des sous-ensembles (powerset) d'un ensemble donné.
void	printPowerset(const std::vector<std::vector<int> > &powerset)
{
	std::cout << "{ ";
	for (std::size_t i = 0; i < powerset.size(); i++)
	{
		std::cout << "{";
		for (std::size_t k = 0; k < powerset[i].size(); k++)
		{
			std::cout << powerset[i][k];

			if (k + 1 < powerset[i].size())
				std::cout << ", ";
		}
		std::cout << "}";

		if (i + 1 < powerset.size())
			std::cout << ", ";
	}

	std::cout << " }" << std::endl;
}

int	main(int argc, char **argv)
{
	std::vector<int>	set;

	for (int i = 1; i < argc; i++)
	{
		char	*end;
		long	value = std::strtol(argv[i], &end, 10);

		if (*end != '\0')
		{
			std::cerr << ERROR(8, "invalid element: " << argv[i]) << std::endl;
			return (1);
		}
		set.push_back(value);
	}

	std::vector<std::vector<int> >	result = powerset(set);

	std::cout << RESULT(8, "") << std::endl;
	printPowerset(result);

	return (0);
}