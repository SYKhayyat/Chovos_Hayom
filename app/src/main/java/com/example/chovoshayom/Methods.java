package com.example.chovoshayom;

import static com.example.chovoshayom.TasksSetup.set;

import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.HashSet;

public class Methods {
    public static HashSet<String> finished = new HashSet<>();
    public static HashSet<Task> currentSet = new HashSet<>();

        public static String getFinished(Task task){
            if (task.getLearned() == task.getTotal()){
                finished.add(task.getName());
            }
            if (task.getIsGeneral()){
                for (Task t: task.getChildren()){
                    getFinished(t);
                }
            }
            String allFinished = "You have finished " + finished.size() + " items in " + task.getName();
            for (String s: finished){
                allFinished += "\n" + s;
            }
            return allFinished;
        }

        public static void clearSet(){
            finished.clear();
        }
        public static void saveToSharedPreferences(SharedPreferences.Editor prefsEditor){
            for (Task t: set){
                prefsEditor.putLong(t.getName(), Double.doubleToRawLongBits(t.getLearned()));
                prefsEditor.commit();
            }
        }
    public static void saveToSharedPreferences(SharedPreferences.Editor prefsEditor, int i){
        prefsEditor.commit();
        for (Task t: set){
            prefsEditor.putLong(t.getName(), Double.doubleToRawLongBits(i));
            prefsEditor.commit();
        }
    }

    public static HashSet<Task> getCurrentSet(Task task) {
            currentSet.add(task);
        if (task.getIsGeneral()){
            for (Task t: task.getChildren()){
                getCurrentSet(t);
            }
        }
        return currentSet;
    }
    public static void clearCurrentSet(){
        currentSet.clear();
    }
}
