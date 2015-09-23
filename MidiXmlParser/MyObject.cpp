//
//  MyObject.cpp
//  ReadStaff
//
//  Created by yanbin on 14-8-7.
//
//

#include "ParseExport.h"

MyObject::~MyObject(){
    
}

MyArray::MyArray(int c)
{
    count=0;
    pointers_count=c;
    objects=new MyObject*[pointers_count];
}
MyArray::~MyArray(){
    delete []objects;
}
void MyArray::checkMemory()
{
    if (count>=pointers_count) {
        MyObject **new_objects=new MyObject*[pointers_count*2];
        memcpy(new_objects, objects, count*sizeof(MyObject*));
        delete [] objects;
        objects=new_objects;
        pointers_count*=2;
    }
}

void MyArray::addObject(MyObject* anObject)
{
    if (anObject==NULL) {
        return;
    }
    checkMemory();
    objects[count]=anObject;
    count++;
}
void MyArray::insertObject(MyObject* anObject, int index)
{
    if (anObject==NULL) {
        return;
    }
    checkMemory();
    if (index<count) {
        for (int i=count; i>=index; i--) {
            objects[i]=objects[i-1];
        }
        objects[index]=anObject;
        count++;
    }else{
        objects[count]=anObject;
        count++;
    }
}

void MyArray::removeAllObjects()
{
    for (int i=0; i<count; i++) {
        MyObject *obj=objects[i];
        delete obj;
    }
}
MyObject* MyArray::lastObject()
{
    if (count>0) {
        return objects[count-1];
    }
    return NULL;
}

MyString::MyString(int l)
{
    length=0;
    buffer_length=l;
    buffer=new char[buffer_length];
    buffer[0]=0;
}
MyString::~MyString(){
    delete []buffer;
    buffer=0;
    buffer_length=0;
    length=0;
}

char *MyString::getBuffer()
{
    return buffer;
}
void MyString::checkMemory(int len)
{
    if (length+len>=static_cast<int>(buffer_length-1)) {
        while (buffer_length<static_cast<unsigned long>(length+len+1)) {
            buffer_length*=2;
        }
        char *new_objects=new char[buffer_length];
        //int count=pointers_count*sizeof(MyObject*);
        memcpy(new_objects, buffer, length*sizeof(char));
        delete []buffer;
        buffer=new_objects;
    }
}

void MyString::appendString(const char* anString, int len)
{
    if (this==NULL) {
        //error, null pointer
        return;
    }
    if (anString==NULL) {
        return;
    }
    checkMemory(len);
    memcpy(buffer+length, anString, len);
    length+=len;
    buffer[length]=0;
}
void MyString::appendString(const char* anString)
{
    appendString(anString, strlen(anString));
}
void MyString::appendString(MyString *anString)
{
    appendString(anString->getBuffer(), anString->length);
}