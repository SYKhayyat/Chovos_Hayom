package com.example.chovoshayom;

import android.content.SharedPreferences;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.view.View;

import com.example.chovoshayom.databinding.ActivitySettingsBinding;
import com.google.android.material.switchmaterial.SwitchMaterial;

public class SettingsActivity extends AppCompatActivity {

    private ActivitySettingsBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SharedPreferences sharedPreferences = getSharedPreferences("Settings", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        binding = ActivitySettingsBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        SwitchMaterial switchNight = findViewById(R.id.switch_night);
        SwitchMaterial switchCalculate = findViewById(R.id.switch_calculate);
        SwitchMaterial switchRead = findViewById(R.id.switch_read);
        switchNight.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                prefsEditor.putInt("Day_Night", 1);
                prefsEditor.commit();
            } else {
                prefsEditor.putInt("Day_Night", 0);
                prefsEditor.commit();
            }
        });
        switchCalculate.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                prefsEditor.putInt("Advanced_Calculation", 1);
                prefsEditor.commit();
            } else {
                prefsEditor.putInt("Advanced_Calculation", 0);
                prefsEditor.commit();
            }
        });
        switchRead.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                prefsEditor.putInt("Read_Only", 1);
                prefsEditor.commit();
            } else {
                prefsEditor.putInt("Read_Only", 0);
                prefsEditor.commit();
            }
        });
    }

}