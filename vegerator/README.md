## 🌲 MSV Vegetation Generator: User Manual

_A guide to the intended end-user experience when using the script._

---

### Workflow

1.  Run the `MSV_VegetationGenerator.lua` script.
2.  The GUI window opens (see mockup).
    > **Nice to have:** The GUI window can be resized and have its colors changed in an options/prefs view.

3.  Select **Dir/Library** (see the 'magnifying glass' in the mockup).
4.  From the search view, choose which sound you would like to use as your first layer.
5.  The user can add more layers (max 5) by choosing more sounds from the search view (see "Layers" in the mockup).
    * The user can remove layers by simply pressing the "X" button.
    * Whenever a layer is added, the script will create folders and child tracks in Reaper, allowing for real-time playback of the sounds put together.

6.  Choose what types of variations you'd like to create: **Enter**, **Exit**, **Loop**, or **3P** (distant assets).
    > **Note:** If there are no 3P recordings, the user could potentially use the 1P assets (near assets) and apply processing directly on the master channel.

7.  Apply global or layer-specific settings:
    * **Global:** Volume or pitch randomization can be applied to each individual asset.
    * **Layer-specific:** Specific volume, pitch, offset, and fades can be applied to an entire layer.

8.  Finally, **Apply** the changes.
    * The newly created vegetation files will be neatly organized in your Reaper session.
    * The changes can be reverted (see mockup).
    * The layered assets will have a region automatically created for easier export, named with the correct type (e.g., `fast_x`).
    * From here, more modifications can be made on the tracks or master track.

---

### Reaper Session Organization

After applying changes, the script organizes all the new assets into parent and child tracks.

_Parent and child tracks being created by the script. Child tracks increase with the amount of layers._
