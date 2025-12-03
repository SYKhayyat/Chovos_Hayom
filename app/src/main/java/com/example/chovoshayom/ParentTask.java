package com.example.chovoshayom;

import java.io.Serializable;

import java.io.Serializable;

public class ParentTask extends Task implements Serializable {
    private Task[] children;

    public ParentTask(){
        super();
        super.setIsGeneral(true);
    }
    public ParentTask(String name, String unitName, Task[] children){
        super();
        super.setName(name);
        super.setUnitName(unitName);
        super.setIsGeneral(true);
        this.children = children;
    }

    public ParentTask(String name, String unitName){
        super.setIsGeneral(true);
        setName(name);
        setUnitName(unitName);
    }
    public void setChildren(Task[] children){
        this.children = children;
    }
    public Task[] getChildren(){
        Task[] childrenList = new Task[children.length];
        System.arraycopy(children, 0, childrenList, 0, children.length);
        return childrenList;
    }
    public String[] getChildrenStrings(){
        String[] childrenList = new String[children.length];
        int i = 0;
        for (Task task: children){
            childrenList[i] = task.getName();
            i++;
        }
        return childrenList;
    }
    public void setTotal(){
        double total = 0;
        for (Task task: children){
            total += task.getTotal();
        }
        super.setTotal(total);
    }

    public void setLearned(){
        double learned = 0;
        for (Task task: children){
            learned += task.getLearned();
        }
        reset(learned);
    }

    }
