package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;
import static com.example.chovoshayom.TasksSetup.bereishis;
import static com.example.chovoshayom.TasksSetup.set;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

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

        FloatingActionButton fab = findViewById(R.id.fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                ArrayList<String> finished = new ArrayList<>();
                TasksSetup.setupSet();
                Methods.getFinished(finished);
                String allFinished = "You have finished " + finished.size() + " items.";
                for (String s: finished){
                    allFinished += "\n" + s;
                }
                Snackbar.make(view, allFinished, Snackbar.LENGTH_LONG)
                        .setAction("Action", null).show();
            }
        });
        setupButtons(task, setting);
    }

    public void setupButtons(Task task, String setting){
        TextView greeting = findViewById(R.id.greeting);
        Button myButton = findViewById(R.id.buttonForChange);
        EditText myEditText = (EditText)  findViewById(R.id.input_box);

        if (setting.equals("add")){
            String toAdd = "Add " + task.getUnitName() + ":";
            greeting.setText(toAdd);
            myButton.setText("Add");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    String input = myEditText.getText().toString();
                    double amount = Double.parseDouble(input);
                    Log.i("TaskA", input);
                    Log.i("TaskB", String.valueOf(amount));
                    task.add(amount);
                    Log.i("TaskC", String.valueOf(task.getLearned()));
                    Intent returnIntent = new Intent();
                    returnIntent.putExtra("result",task);
                    setResult(Activity.RESULT_OK,returnIntent);
                    Log.i("Bereishis", String.valueOf(bereishis.getLearned()));
                    finish();
                }
            });
        }
        else if (setting.equals("reset")){
            String toReset = "Reset " + task.getUnitName() + ":";
            greeting.setText(toReset);
            myButton.setText("Reset");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    String input = myEditText.getText().toString();
                    double amount = Double.parseDouble(input);
                    task.reset(amount);
                    Intent returnIntent = new Intent();
                    returnIntent.putExtra("result",task);
                    setResult(Activity.RESULT_OK,returnIntent);
                    finish();
                }
            });
        }
    }
}