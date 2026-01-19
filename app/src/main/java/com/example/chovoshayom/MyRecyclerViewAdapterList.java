package com.example.chovoshayom;

// Source - https://stackoverflow.com/a
// Posted by Suragch, modified by community. See post 'Timeline' for change history
// Retrieved 2025-11-24, License - CC BY-SA 4.0

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

public class MyRecyclerViewAdapterList extends RecyclerView.Adapter<MyRecyclerViewAdapterList.ViewHolder> {

    private int[] mNames;
    private String[] mData;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;

    // data is passed into the constructor
    MyRecyclerViewAdapterList(Context context, int[] names, String[] data) {
        this.mInflater = LayoutInflater.from(context);
        this.mNames = names;
        this.mData = data;
    }

    // inflates the cell layout from xml when needed
    @Override
    @NonNull
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = mInflater.inflate(R.layout.card_layout_list, parent, false);
        return new ViewHolder(view);
    }


    // binds the data to the TextView in each cell
    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        String s = Integer.toString(mNames[position]);
        holder.myTextNames.setText(s);
        holder.myTextData.setText(mData[position]);

    }

    // total number of cells
    @Override
    public int getItemCount() {
        return mData.length;
    }


    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView myTextNames;
        TextView myTextData;


        ViewHolder(View itemView) {
            super(itemView);
            myTextData = itemView.findViewById(R.id.itemNames);
            myTextNames = itemView.findViewById(R.id.itemData);
            itemView.setOnClickListener(this);
        }

        @Override
        public void onClick(View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAbsoluteAdapterPosition());
        }
    }

    // convenience method for getting data at click position
    int getItem(int id) {
        return mNames[id];
    }

    // allows clicks events to be caught
    void setClickListener(ItemClickListener itemClickListener) {
        this.mClickListener = itemClickListener;
    }

    // parent activity will implement this method to respond to click events
    public interface ItemClickListener {
        void onItemClick(View view, int position);
    }
}
