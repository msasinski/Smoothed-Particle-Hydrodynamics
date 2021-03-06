#ifndef _VectorMath_
#define _VectorMath_

#include <math.h>

const double PI=3.14159265;


//An object to represent a 3D vector or a 3D point in space
class Vector3D
{
public:
    double x;									// the x value of this Vector3D
    double y;									// the y value of this Vector3D
    double z;									// the z value of this Vector3D

    Vector3D():  // Constructor to set x = y = z = 0
        x(0),
        y(0),
        z(0)
    {

    }

    Vector3D(double x, double y, double z):			// Constructor that initializes this Vector3D to the intended values of x, y and z
        x(x),
        y(y),
        z(z)
    {

    }

    Vector3D& operator= (const Vector3D &v)			// operator= sets values of v to this Vector3D. example: v1 = v2 means that values of v2 are set onto v1
    {
        x = v.x;
        y = v.y;
        z = v.z;
        return *this;
    }

    Vector3D operator+ (const Vector3D &v)	const			// operator+ is used to add two Vector3D's. operator+ returns a new Vector3D
    {
        return Vector3D(x + v.x, y + v.y, z + v.z);
    }

    Vector3D operator- (const Vector3D &v)	const			// operator- is used to take difference of two Vector3D's. operator- returns a new Vector3D
    {
        return Vector3D(x - v.x, y - v.y, z - v.z);
    }

    Vector3D operator* (double value)	const		// operator* is used to scale a Vector3D by a value. This value multiplies the Vector3D's x, y and z.
    {
        return Vector3D(x * value, y * value, z * value);
    }


    Vector3D operator/ (double value)	const		// operator/ is used to scale a Vector3D by a value. This value divides the Vector3D's x, y and z.
    {
        return Vector3D(x / value, y / value, z / value);
    }

    Vector3D& operator+= (const Vector3D &v)			// operator+= is used to add another Vector3D to this Vector3D.
    {
        x += v.x;
        y += v.y;
        z += v.z;
        return *this;
    }

    Vector3D& operator-= (const Vector3D &v)			// operator-= is used to subtract another Vector3D from this Vector3D.
    {
        x -= v.x;
        y -= v.y;
        z -= v.z;
        return *this;
    }

    Vector3D& operator*= (double value)			// operator*= is used to scale this Vector3D by a value.
    {
        x *= value;
        y *= value;
        z *= value;
        return *this;
    }

    Vector3D& operator/= (double value)			// operator/= is used to scale this Vector3D by a value.
    {
        x /= value;
        y /= value;
        z /= value;
        return *this;
    }


    Vector3D operator- ()	const					// operator- is used to set this Vector3D's x, y, and z to the negative of them.
    {
        return Vector3D(-x, -y, -z);
    }

    double length()		const						// length() returns the length of this Vector3D
    {
        return sqrt(x*x + y*y + z*z);
    }

    double operator*(const Vector3D &v) const
    {
        return x*v.x + y*v.y + z*v.z;
    }

    Vector3D operator%(const Vector3D &v) const
    {
        Vector3D t;
        t.x=y*v.z-z*v.y;
        t.y=z*v.x-x*v.z;
        t.z=x*v.y-y*v.x;
        return t;
    }

    bool operator==(const Vector3D &v) const
    {
        if((x==v.x)&&(y==v.y)&&(z==v.z))
            return true;
        else
            return false;
    }

};






#endif
