#include "owWorldSimulation.h"
#include <stdio.h>
#include <iostream>

extern bool load_from_file = false;

int main(int argc, char **argv)
{
    if(argc == 1)
    {
        std::cout << "Sibernetic: no arguments, run method executing\n";
        run( argc, argv);
    }
    else
    {

        bool graph = true;
        bool load_to = false;

        for(int i = 1; i<argc; i++)
        {
            //run without graphics
            if(strncmp(argv[i], "-no_g", 5) == 0)
                graph = false;

            //run load config to file mode
            if(strncmp(argv[i], "-l_to", 5) == 0)
            {
                std::cout << "l_to flag, Sibernetic will save simulation results to disk\n";
                graph = false;
                load_to = true;
            }

            //run load config from file mode
            if(strncmp(argv[i], "-l_from", 7) == 0)
            {
                graph = true;
                load_from_file = true;
            }
        }

        run( argc, argv, graph, load_to);

    }

    return 0;

}
