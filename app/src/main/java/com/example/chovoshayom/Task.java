package com.example.chovoshayom;


import com.google.gson.Gson;

import java.io.Serializable;

public class Task implements Serializable {
    private String name;
    private String unitName;
    private double learned;
    private double total;

    public Task(String name, String unitName, double total){
        this.name = name;
        this.unitName = unitName;
        learned = 0;
        this.total = total;
    }

    public String getName(){
        return name;
    }

    public String getUnitName(){
        return unitName;
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

    public boolean finished(){
        return learned == total;
    }

    public void add(double added){
        learned += learned;
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

}
