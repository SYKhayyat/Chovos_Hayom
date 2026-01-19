package com.example.chovoshayom;


import com.google.gson.Gson;

import java.io.Serializable;

public class Task implements Serializable, Comparable{
    private String name;
    private double learned;
    private double total;
    private int[] learnedList;
    boolean isGeneral;
    public Task(String name, boolean isGeneral){
        this.name = name;
        this.isGeneral = isGeneral;
        learned = 0;
        total = 0;
    }

    public Task(){
        name = "";
        isGeneral = false;
        learned = 0;
        total = 0;
    }

    public String getName(){
        return name;
    }

    public double getLearned(){
        return learned;
    }

    public double getTotal(){
        return total;
    }

    public double getPercentage(){
        if (total <= 0){
            return -1;
        }
        double originalNumber = 100 * (learned)/total;
        double roundedNumber = Math.round(originalNumber * 100.0) / 100.0;
        return roundedNumber;
    }

    public boolean getIsGeneral(){
        return isGeneral;
    }
    public int[] getLearnedList(){
        return learnedList;
    }
    public void setLearnedList(int[] list){
        learnedList = list;
    }

    public boolean finished(){
        return learned == total;
    }

    public void setName(String name){
        this.name = name;
    }
    public void setTotal(double total){
        this.total = total;
    }
    public void setIsGeneral(boolean isGeneral){
        this.isGeneral = isGeneral;
    }
    public void add(double added){
        if (learned + added <= total){
            learned += added;
        }
        else if (learned + added - 1 < total){
            learned = total;
        }
    }
    public void reset(double value){
        learned = value;
    }
    @Override
    public String toString(){
        return "In " + name + ", you have finished " + learned + " of " + total + "'";
    }
    public boolean equals(Task task){
        return getName().equals(task.getName());
    }
    public static Task getTaskFromJSON (String json)
    {
        Gson gson = new Gson ();
        return gson.fromJson (json, Task.class);
    }

    public Task getParent(){
        return null;
    }
    public boolean isChild(){
        return getParent() != null;
    }

    public Task[] getChildren(){
        return null;
    }


    @Override
    public int compareTo(Object o) {
        return toString().compareTo(o.toString());
    }

    public double getRemaining(){
        return total - learned;
    }

    public int getOffset() {
        return 0;
    }
}
