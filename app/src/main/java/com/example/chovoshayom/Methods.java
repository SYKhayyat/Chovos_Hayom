package com.example.chovoshayom;

import static com.example.chovoshayom.TasksSetup.set;

import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.HashSet;

public class Methods {
        public static void getFinished(ArrayList<String> finished){
            for (Task t: set){
                if (t.getLearned() == t.getTotal()){
                    finished.add(t.getName());
                }
            }
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
}
