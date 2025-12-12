package com.example.chovoshayom;

import java.io.Serializable;

public class ChildTask extends ParentTask implements Serializable {
    private Task parent;

    public ChildTask(){
        super();
        super.setIsGeneral(true);
        parent = null;
    }
    public ChildTask(Task parent){
        super();
        super.setIsGeneral(true);
        this.parent = parent;
    }
    public ChildTask(String name, Task[] children, Task parent){
        super();
        super.setName(name);
        super.setIsGeneral(true);
        super.setChildren(children);
        this.parent = parent;
    }

    public ChildTask(String name, Task parent){
        super.setName(name);
        super.setIsGeneral(true);
        this.parent = parent;
    }
    public void setParent(Task parent){
        this.parent = parent;
    }

    @Override
    public Task getParent(){
        return parent;
    }
}
