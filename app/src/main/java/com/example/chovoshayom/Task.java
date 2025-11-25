package com.example.chovoshayom;


import android.os.Parcelable;

public class Task implements Parcelable {
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

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(android.os.Parcel dest, int flags) {
        dest.writeString(this.name);
        dest.writeString(this.unitName);
        dest.writeDouble(this.learned);
        dest.writeDouble(this.total);
    }

    protected Task(android.os.Parcel in) {
        this.name = in.readString();
        this.unitName = in.readString();
        this.learned = in.readDouble();
        this.total = in.readDouble();
    }

    public static final android.os.Parcelable.Creator<Task> CREATOR = new android.os.Parcelable.Creator<Task>() {
        @Override
        public Task createFromParcel(android.os.Parcel source) {
            return new Task(source);
        }

        @Override
        public Task[] newArray(int size) {
            return new Task[size];
        }
    };
}
