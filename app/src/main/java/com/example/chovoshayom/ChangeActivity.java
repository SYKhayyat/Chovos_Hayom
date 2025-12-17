package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;
import static com.example.chovoshayom.TasksSetup.bereishis;
import static com.example.chovoshayom.TasksSetup.set;

import android.app.Activity;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityChangeBinding;

import java.util.ArrayList;

public class ChangeActivity extends AppCompatActivity {

    private ActivityChangeBinding binding;

    String setting;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent myIntent = getIntent();
        setting = myIntent.getStringExtra("setting");

        binding = ActivityChangeBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setupButtons(task, setting);
    }

    public void setupButtons(Task task, String setting){
        TextView greeting = findViewById(R.id.greeting);
        Button myButton = findViewById(R.id.buttonForChange);

        if (setting.equals("add")){
            String toAdd = "Add: ";
            greeting.setText(toAdd);
            myButton.setText("Add");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    checkInput(setting);
            }});
        }
        else if (setting.equals("reset")){
            String toReset = "Reset: ";
            greeting.setText(toReset);
            myButton.setText("Reset");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    checkInput(setting);
                }
            });
        }
    }

    private void checkInput(String setting){
        EditText myEditText = (EditText)  findViewById(R.id.input_box);
        String input = myEditText.getText().toString();
        double amount = Double.parseDouble(input);
        Log.i("task", task.getName());
        if (setting.equals("add") && (amount > task.getTotal() - task.getLearned() || (0 - amount) > task.getLearned())
                || setting.equals("reset") && (amount > task.getTotal() || amount < 0))
        {
            AlertDialog.Builder builder = new AlertDialog.Builder(ChangeActivity.this);
            builder.setMessage("That number makes no sense!")
                    .setTitle("Invalid input");
            builder.setNegativeButton("Retry", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                }
            });
            AlertDialog dialog = builder.create();
            dialog.show();
        } else if (amount < 0){
            AlertDialog.Builder builder = new AlertDialog.Builder(ChangeActivity.this);
            builder.setMessage("Are you sure that you want to enter in a negative number?")
                    .setTitle("Are you sure?");
            builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    finishOff(amount, setting);
                }
            });
            builder.setNegativeButton("No", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                }
            });
            AlertDialog dialog = builder.create();
            dialog.show();
        }
        else {
            finishOff(amount, setting);
        }
    }
    private void finishOff(double amount, String setting){
        if (setting.equals("add")){
            task.add(amount);}
        else if (setting.equals("reset")){
            task.reset(amount);
        }
        Intent returnIntent = new Intent();
        returnIntent.putExtra("result",task);
        setResult(Activity.RESULT_OK,returnIntent);
        finish();
    }
}