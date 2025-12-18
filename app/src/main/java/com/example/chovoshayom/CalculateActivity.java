package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;
import static com.example.chovoshayom.TasksSetup.bereishis;


import android.app.Activity;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.icu.util.Calendar;
import android.os.Bundle;

import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;

import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityCalculateBinding;

import java.util.ArrayList;

public class CalculateActivity extends AppCompatActivity {
    private ActivityCalculateBinding binding;
    SharedPreferences prefs2;

    double days;
    double weeks;
    double months;
    double shabbosAmount;
    double years;
    Calendar calendar;
    int i;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityCalculateBinding.inflate(getLayoutInflater());

        setContentView(binding.getRoot());
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        ActionBar actionBar = getSupportActionBar();
        actionBar.setDisplayHomeAsUpEnabled(true);
        ExtendedFloatingActionButton fab = findViewById(R.id.fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                String allFinished = Methods.getFinished(task);
                Methods.clearSet();
                Snackbar.make(view, allFinished, Snackbar.LENGTH_LONG)
                        .setAction("Action", null).show();
            }
        });

        prefs2 = getSharedPreferences("Settings", MODE_PRIVATE);
        setupFields();
        setDayOfWeek();
        Button calc = findViewById(R.id.buttonForCalculation);
        if (prefs2.getInt("Advanced_Calculation", -1) == 0 || prefs2.getAll().isEmpty()){
            reconfigureXmlSimple();
        }
        else if (prefs2.getInt("Advanced_Calculation", -1) == 1){
            reconfigureXmlAdvanced();
        }
        calc.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                double amount = getAmountPerDay();
                if (prefs2.getInt("Advanced_Calculation", -1) == 0 || prefs2.getAll().isEmpty()){
                    days = daysUntilFinishedSimple(amount);
                    weeks = weeksUntilFinishedSimple(amount);
                    months = monthsUntilFinishedSimple(amount);
                    years = yearsUntilFinishedSimple(amount);
                }
                else if (prefs2.getInt("Advanced_Calculation", -1) == 1){
                    double shabbosAmount = getAmountPerShabbos();
                    days = daysUntilFinishedAdvanced(amount, shabbosAmount);
                    weeks = weeksUntilFinishedAdvanced(amount, shabbosAmount);
                    months = monthsUntilFinishedAdvanced(amount, shabbosAmount);
                    years = yearsUntilFinishedAdvanced(amount, shabbosAmount);
                }
                displayTimeUntilFinished(days, weeks, months, years);
            }});
        setupButton();
    }

    private void setDayOfWeek() {
        calendar = Calendar.getInstance();
        int day = calendar.get(Calendar.DAY_OF_WEEK);
        switch (day) {
            case Calendar.SUNDAY:
            case Calendar.SATURDAY:
                i = 6;
                break;
            case Calendar.MONDAY:
                i = 5;
                break;
            case Calendar.TUESDAY:
                i = 4;
                break;
            case Calendar.WEDNESDAY:
                i = 3;
                break;
            case Calendar.THURSDAY:
                i = 2;
                break;
            case Calendar.FRIDAY:
                i = 1;
                break;
        }
    }

    private double getAmountPerShabbos() {
        EditText myEditText = findViewById(R.id.shabbosEnter);
        String inputShab = myEditText.getText().toString();
        return Double.parseDouble(inputShab);
    }

    private double daysUntilFinishedAdvanced(double amount, double shabbosAmount) {
        return daysMethod(task.getRemaining(), amount, shabbosAmount);
    }

    private double daysMethod(double remaining, double amount, double shabbosAmount) {
        if (task.getRemaining() / (((6 * amount) + shabbosAmount)/ 7) > 50){
            return task.getRemaining() / (((6 * amount) + shabbosAmount)/ 7);
        }
        if (amount * i >= remaining){
            return remaining / amount;
        }
        else {
            return 7 + daysMethod((task.getRemaining() - ((amount * 6) + shabbosAmount)), amount, shabbosAmount);
        }
    }

    private double weeksUntilFinishedAdvanced(double amount, double shabbosAmount) {
        return task.getRemaining() / ((6 * amount) + shabbosAmount);
    }

    private double monthsUntilFinishedAdvanced(double amount, double shabbosAmount) {
        return task.getRemaining() / ((25.5 * amount) + (4.5 *shabbosAmount));
    }

    private double yearsUntilFinishedAdvanced(double amount, double shabbosAmount) {
        return task.getRemaining() / ((313 * amount) + (52 *shabbosAmount));
    }

    private void reconfigureXmlSimple() {
        TextView shabbosText = findViewById(R.id.shabbosText);
        shabbosText.setVisibility(View.GONE);
        EditText shabbosEnter = findViewById(R.id.shabbosEnter);
        shabbosEnter.setVisibility(View.GONE);
    }

    private void reconfigureXmlAdvanced() {
        TextView shabbosText = findViewById(R.id.shabbosText);
        shabbosText.setVisibility(View.VISIBLE);
        shabbosText.setText(R.string.shabbos_amount);
        EditText shabbosEnter = findViewById(R.id.shabbosEnter);
        shabbosEnter.setVisibility(View.VISIBLE);
    }

    private void setupFields() {
        TextView greeting = findViewById(R.id.calculateText);
        if (prefs2.getInt("Advanced_Calculation", -1) == 0){
            greeting.setText(R.string.welcome_to_the_siyum_calculator_enter_the_amount_you_learn_daily_and_you_will_see_when_you_will_finish);
        } else if (prefs2.getInt("Advanced_Calculation", -1) == 1){
            greeting.setText(R.string.welcome_to_the_siyum_calculator_enter_the_amount_you_do_daily_as_well_as_the_amount_you_learn_on_shabbos_and_you_will_see_when_you_will_finish);
        }
        TextView daily = findViewById(R.id.dailyText);
        daily.setText(R.string.daily_amount);
    }

    private double getAmountPerDay() {
        EditText myEditText = findViewById(R.id.dailyEnter);
        String input = myEditText.getText().toString();
        return Double.parseDouble(input);
    }

    private double daysUntilFinishedSimple(double amount) {
        double returner = task.getRemaining() / amount;
        return Math.round(returner * 100.0) / 100.0;
    }

    private double weeksUntilFinishedSimple(double amount) {
        double returner = task.getRemaining() / (amount * 7);
        return Math.round(returner * 100.0) / 100.0;
    }

    private double monthsUntilFinishedSimple(double amount) {
        double returner = task.getRemaining() / (amount * 30);
        return Math.round(returner * 100.0) / 100.0;
    }

    private double yearsUntilFinishedSimple(double amount) {
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
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int itemId = item.getItemId();
        if (itemId == R.id.action_statistics) {
            showStatistics();
            return true;
        }
        else if (itemId == android.R.id.home){
            Intent returnIntent = new Intent();
            if (task.getParent() != null){
                task = task.getParent();}
            TasksSetup.setupLearned();
            Log.i("Bereishis", String.valueOf(bereishis.getLearned()));
            returnIntent.putExtra("result",task);
            setResult(Activity.RESULT_OK,returnIntent);
            Log.i("Task", task.getName());
            finish();
            return true;
        }
        else if (itemId == R.id.action_save) {
            savePreferences();
            return true;
        } else if (itemId == R.id.calculate) {
            showCalculate();
            return true;
        }else if (itemId == R.id.action_reset_stats) {
            resetAll();
            return true;
        } else if (itemId == R.id.action_settings) {
            showSettings();
            return true;
        } else if (itemId == R.id.action_about) {
            showAbout();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    private void showCalculate() {
        Intent intent = new Intent(this, CalculateActivity.class);
        startActivity(intent);
    }

    private void showStatistics() {
        Intent intent = new Intent(this, StatisticsActivity.class);
        startActivity(intent);
    }


    private void resetAll() {
        if (prefs2.getInt("Read_Only", -1) != 1){
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage("This will reset everything to zero!")
                    .setTitle("Are you sure?");
            builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
                    SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
                    Methods.saveToSharedPreferences(prefsEditor, 0);
                    finish();
                }
            });
            builder.setNegativeButton("No", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    finish();
                }
            });
            AlertDialog dialog = builder.create();}
        else {
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage("Read Only mode is on.")
                    .setTitle("Not Enabled!");
            AlertDialog dialog = builder.create();}

    }

    private void showSettings() {
        Intent intent = new Intent(this, SettingsActivity.class);
        startActivity(intent);
    }
    private void showAbout() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage("Chovos Hayom is a simple app, designed by Shaul Khayyat, which allows you to keep track of your learning and calculate when your next siyum will be.")
                .setTitle("Chovos Hayom");
        AlertDialog dialog = builder.create();
        dialog.show();
    }
    private void savePreferences() {
        SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        Methods.saveToSharedPreferences(prefsEditor);
    }

}