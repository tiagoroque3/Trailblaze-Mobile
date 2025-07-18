package pt.unl.fct.di.apdc.trailblaze.util;

import java.util.List;

public class CreateTrailRequest {
    public String name;
    public String worksheetId;
    public TrailVisibility visibility;
    public List<TrailPoint> points;
    public List<WorksheetProximity> worksheetProximities;
    public String initialObservation;

    public boolean isValid() {
        return name != null && !name.trim().isEmpty() 
               && worksheetId != null && !worksheetId.trim().isEmpty()
               && points != null;
    }
}