#include <Python.h>
#ifndef PYRAMIDALSIMULATION_H
#define PYRAMIDALSIMULATION_H
#include <vector>

using namespace std;

class PyramidalSimulation
{

private:
    PyObject *pName, *pModule, *pValue, *pClass, *pInstance;
    vector<float> unpackPythonList(PyObject*);

public:
    vector<float> run();
    PyramidalSimulation(); 
};

#endif
