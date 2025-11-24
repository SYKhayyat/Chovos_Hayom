package com.example.chovoshayom;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.chovoshayom.R;

public class RecyclerAdapter extends RecyclerView.Adapter<RecyclerAdapter.ViewHolder> {
    final private String[] tasks = {
            "Tanach",
            "Mishnayos",
            "Shas",
            "Yerushalmi",
            "Rambam",
            "Tur",
            "Shulchan Aruch",
            "Mishna Berurah"
    };

    final private int[] images = {R.drawable.android_tanach,
            R.drawable.android_mishnayos,
            R.drawable.android_shas,
            R.drawable.android_yerushalmi,
            R.drawable.android_rambam,
            R.drawable.android_tur,
            R.drawable.android_shulchan_aruch,
            R.drawable.android_mishna_berurah};

    static class ViewHolder extends RecyclerView.ViewHolder {
            ImageView itemImage;
            TextView itemTitle;

            ViewHolder(View itemView) {
                super(itemView);
                itemImage = itemView.findViewById(R.id.itemImage);
                itemTitle = itemView.findViewById(R.id.itemTitle);
            }
        }

     @NonNull
    @Override
    public ViewHolder onCreateViewHolder(ViewGroup view_group, int i){
        View view = LayoutInflater.from(view_group.getContext())
                .inflate(R.layout.card_layout, view_group, false);
        return new ViewHolder(view);
     }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, int i) {
        viewHolder.itemTitle.setText(tasks[i]);
        viewHolder.itemImage.setImageResource(images[i]);
    }

    @Override
    public int getItemCount() {
        return tasks.length;
    }

    // convenience method for getting data at click position
    String getItem(int id) {
        return tasks[id];
    }


}
