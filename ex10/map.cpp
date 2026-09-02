#include "colors.hpp"
#include <iostream>
#include <cstdint>
#include <iomanip>

// Mappe deux entiers non signés de 16 bits sur un
// nombre à virgule flottante entre 0 et 1 en utilisant l'interleaving des bits.
// L'interleaving des bits consiste à alterner les bits des deux entiers
// pour former un entier de 32 bits.
double	map(uint16_t x, uint16_t y)
{
	uint32_t	result = 0;

	for (int i = 0; i < 16; i++)
	{
		result = result | (((uint32_t)(x >> i) & 1) << (2 * i));
		result = result | (((uint32_t)(y >> i) & 1) << (2 * i + 1));
	}
	return ((double)result / (double)UINT32_MAX);
}

int	main(int argc, char **argv)
{
	if (argc != 3)
	{
		std::cerr << USAGE(10, argv[0] << " <x> <y>") << std::endl;
		return (1);
	}

	uint16_t	x = std::strtoul(argv[1], nullptr, 10);
	uint16_t	y = std::strtoul(argv[2], nullptr, 10);

	std::cout << std::setprecision(std::numeric_limits<double>::max_digits10)
		<< RESULT(10, map(x, y)) << std::endl;

	return (0);
}