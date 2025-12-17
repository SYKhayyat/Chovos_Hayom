package com.example.chovoshayom;

import android.content.SharedPreferences;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;

import android.view.View;

import com.example.chovoshayom.databinding.ActivitySettingsBinding;
import com.google.android.material.switchmaterial.SwitchMaterial;

public class SettingsActivity extends AppCompatActivity {

    private ActivitySettingsBinding binding;
    SharedPreferences prefs2;
    SwitchMaterial switchNight;
    SwitchMaterial switchCalculate;
    SwitchMaterial switchRead;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SharedPreferences sharedPreferences = getSharedPreferences("Settings", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        binding = ActivitySettingsBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        prefs2 = getSharedPreferences("Settings", MODE_PRIVATE);
        if (prefs2.getInt("Day_Night", -1) == 1){
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES);
        }
        else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
        }
        switchNight = findViewById(R.id.switch_night);
        switchCalculate = findViewById(R.id.switch_calculate);
        switchRead = findViewById(R.id.switch_read);
        setLooks();
        switchNight.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                switchNight.setChecked(true);
                prefsEditor.putInt("Day_Night", 1);
                prefsEditor.commit();
            } else {
                switchNight.setChecked(false);
                prefsEditor.putInt("Day_Night", 0);
                prefsEditor.commit();
            }
        });
        switchCalculate.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                switchCalculate.setChecked(true);
                prefsEditor.putInt("Advanced_Calculation", 1);
                prefsEditor.commit();
            } else {
                switchCalculate.setChecked(false);
                prefsEditor.putInt("Advanced_Calculation", 0);
                prefsEditor.commit();
            }
        });
        switchRead.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                switchRead.setChecked(true);
                prefsEditor.putInt("Read_Only", 1);
                prefsEditor.commit();
            } else {
                switchRead.setChecked(false);
                prefsEditor.putInt("Read_Only", 0);
                prefsEditor.commit();
            }
        });
    }//TODO show the real state of settings

    private void setLooks() {
        switchNight.setChecked(prefs2.getInt("Day_Night", -1) == 1);
        switchCalculate.setChecked(prefs2.getInt("Advanced_Calculation", -1) == 1);
        switchRead.setChecked(prefs2.getInt("Read_Only", -1) == 1);
    }

}