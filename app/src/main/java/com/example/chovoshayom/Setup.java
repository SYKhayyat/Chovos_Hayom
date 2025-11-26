//package com.example.chovoshayom;
//
//import android.content.Context;
//import android.content.Intent;
//import android.widget.Button;
//import android.widget.ProgressBar;
//import android.widget.TextView;
//
//import androidx.core.view.accessibility.AccessibilityEventCompat;
//
//public class Setup {
//    public static void setup(Task task, Context context){
//        setName(task, context);
//        setPercentage(task, context);
//        setProgressBar(task, context);
//        setFraction(task, context);
//    }
//
//
//    private static void setName(Task task, Context context){
//        TextView name = new TextView(context);
//        name.setText(task.getName());
////Figure out how to add width, height, constraints, and the lie, programmatically.
//    }
//
//    private static void setPercentage(Task task, Context context) {
//        TextView percent = new TextView(context);
//        double percentFinished = task.getPercentage();
//        String displayPercentage = percentFinished + "%";
//        percent.setText(displayPercentage);
//    }
//
//    private static void setProgressBar(Task task, Context context) {
//       ProgressBar progressBar = new ProgressBar(context);
//        progressBar.setMax((int) task.getTotal());
//        progressBar.setProgress((int) task.getLearned());
//    }
//
//    private static void setFraction(Task task, Context context) {
//        TextView fraction = new TextView(context);
//        String getFraction = task.getLearned() + " / " + task.getTotal();
//        fraction.setText(getFraction);
//    }
//
//    private static void addButtons(Context context){
//        Button add = new Button(context);
//        add.setText("Add!");
//        Button reset = new Button(context);
//        add.setText("Reset");
//    }
//}
