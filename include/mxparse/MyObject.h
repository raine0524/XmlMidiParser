//
//  MyObject.h
//  ReadStaff
//
//  Created by yanbin on 14-8-7.
//
//

#ifndef __ReadStaff__MyObject__
#define __ReadStaff__MyObject__

class PARSE_DLL MyObject {
public:
    ~MyObject();
};

class MyArray:public MyObject {
private:
    int pointers_count;
    void checkMemory();
    
public:
    MyArray(int count=16);
    ~MyArray();
    
    MyObject **objects;
    int count;
    
    void addObject(MyObject* anObject);
    void insertObject(MyObject* anObject, int index);
    void removeAllObjects();
    MyObject* lastObject();
};
#define Delete_MyArray(T, arr) \
{   \
    if (arr) \
    {   \
        for (int i=0; i<arr->count; i++) {  \
            T *s = (T *)arr->objects[i];    \
            delete s;   \
        }   \
        delete arr;   \
        arr=0; \
    } \
}

class PARSE_DLL MyString:public MyObject {
private:
    unsigned long buffer_length;
    void checkMemory(int len);
    char *buffer;
public:
    MyString(int length=128);
    ~MyString();
    
    char *getBuffer();
    int length;
    
    void appendString(const char* anObject, int len);
    void appendString(const char* anObject);
    void appendString(MyString *anObject);
};

#endif /* defined(__ReadStaff__MyObject__) */
