package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;


import android.content.DialogInterface;
import android.os.Bundle;

import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityCalculateBinding;

import java.util.ArrayList;

public class CalculateActivity extends AppCompatActivity {

    private ActivityCalculateBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        binding = ActivityCalculateBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        setupFields();
        Button calc = findViewById(R.id.buttonForCalculation);
        calc.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                double amount = getAmountPerDay();
                double days = daysUntilFinished(amount);
                double weeks = weeksUntilFinished(amount);
                double months = monthsUntilFinished(amount);
                double years = yearsUntilFinished(amount);
                displayTimeUntilFinished(days, weeks, months, years);
            }});
        setupButton();
    }

    private void setupFields() {
        TextView greeting = findViewById(R.id.calculateText);
        greeting.setText("Welcome to the Siyum Calculator. Enter the amount you do daily, and you will see when you will finish.");
        TextView daily = findViewById(R.id.dailyText);
        daily.setText("Daily Amount:");
    }

    private double getAmountPerDay() {
        EditText myEditText = findViewById(R.id.dailyEnter);
        String input = myEditText.getText().toString();
        double amount = Double.parseDouble(input);
        return amount;
    }

    private double daysUntilFinished(double amount) {
        double returner = task.getRemaining() / amount;
        return Math.round(returner * 100.0) / 100.0;
    }

    private double weeksUntilFinished(double amount) {
        double returner = task.getRemaining() / (amount * 7);
        return Math.round(returner * 100.0) / 100.0;
    }

    private double monthsUntilFinished(double amount) {
        double returner = task.getRemaining() / (amount * 30);
        return Math.round(returner * 100.0) / 100.0;
    }

    private double yearsUntilFinished(double amount) {
        double returner = task.getRemaining() / (amount * 365);
        return Math.round(returner * 100.0) / 100.0;
    }

    private void displayTimeUntilFinished(double days, double weeks, double months, double years) {
        String display = "You will finish in: \n" + days + " days,\n"
                + weeks + " weeks,\n" + months + " months,\n" + years + " years.";
        TextView myTextView = findViewById(R.id.result);
        myTextView.setText(display);
    }
    public void setupButton(){
        Button myButton = findViewById(R.id.buttonForDone);
        myButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }});
    }

}