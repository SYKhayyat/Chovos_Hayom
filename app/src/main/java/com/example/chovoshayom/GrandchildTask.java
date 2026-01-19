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
        setupLearnedList();
    }

    private void setupLearnedList() {
        int size = (int) getTotal();
        if (getTotal() - size > .2){
            size ++;
        }
        int[] learned = new int [size];
        for (int i = 0; i < size; i++) {
            learned[i] = 0;
        }
        setLearnedList(learned);
    }

    public void setOffset(int offset){
        this.offset = offset;
    }
    public int getOffset(){
        return offset;
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
