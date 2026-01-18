package com.example.chovoshayom;

import java.io.Serializable;

public class GrandchildTask extends Task implements Serializable {
    private Task parent;
    private int offset;
    public GrandchildTask(){
        super();
        parent = null;
        super.setIsGeneral(false);
    }
    public GrandchildTask(Task parent){
        super();
        this.parent = parent;
        super.setIsGeneral(false);
    }
    public GrandchildTask(String name, double total, Task parent, int offset){
        super.setName(name);
        super.setIsGeneral(false);
        setTotal(total);
        this.parent = parent;
        this.offset = offset;
    }
    public GrandchildTask(String name, double total){
        super.setName(name);
        super.setIsGeneral(false);
        setTotal(total);
    }
    @Override
    public Task getParent(){
        return parent;
    }


}
