#include "colors.hpp"
#include <iostream>
#include <cstdint>
#include <utility>

// Fait l'opération inverse de la fonction map de l'exercice 10.
// Prend un nombre à virgule flottante entre 0 et 1 et retourne
// les deux entiers non signés de 16 bits correspondants en désintercalant les bits.
std::pair<uint16_t, uint16_t>	reverse_map(double n)
{
	uint32_t	value = (uint32_t)std::llround(n * (double)UINT32_MAX);
	uint16_t	x = 0;
	uint16_t	y = 0;

	for (int i = 0; i < 16; i++)
	{
		x = x | (((value >> (2 * i)) & 1) << i);
		y = y | (((value >> (2 * i + 1)) & 1) << i);
	}
	return (std::make_pair(x, y));
}

int	main(int argc, char **argv)
{
	if (argc != 2)
	{
		std::cerr << USAGE(11, argv[0] << " <n>") << std::endl;
		return (1);
	}

	double							n = std::strtod(argv[1], nullptr);
	std::pair<uint16_t, uint16_t>	result = reverse_map(n);

	std::cout << RESULT(11, "(" << result.first << ", " << result.second << ")") << std::endl;

	return (0);
}