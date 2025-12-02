package com.example.chovoshayom;

import java.io.Serializable;

public class GrandchildTask extends Task implements Serializable {
    private Task parent;
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
    public GrandchildTask(String name, double total, Task parent){
        super.setName(name);
        super.setIsGeneral(false);
        setTotal(total);
        this.parent = parent;
        super.setUnitName(parent.getUnitName());
    }
    public GrandchildTask(String name, double total){
        super.setName(name);
        super.setIsGeneral(false);
        setTotal(total);
    }


}
