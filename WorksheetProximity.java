package pt.unl.fct.di.apdc.trailblaze.util;

public class WorksheetProximity {
    public String worksheetId;
    public String worksheetName;
    public String posp;
    public double distanceKm;

    public WorksheetProximity() {}

    public WorksheetProximity(String worksheetId, String worksheetName, String posp, double distanceKm) {
        this.worksheetId = worksheetId;
        this.worksheetName = worksheetName;
        this.posp = posp;
        this.distanceKm = distanceKm;
    }
}