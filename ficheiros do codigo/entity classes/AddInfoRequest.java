package pt.unl.fct.di.apdc.trailblaze.util;

import java.util.List;

public class AddInfoRequest {
    public String activityId;
    public String operationExecutionId;
    public String parcelId;
    public List<String> photos;
    public List<String> gpsTracks;
    public String observations;

    public boolean isValid() {
        // Only activityId is strictly required for adding info to an existing activity
        return activityId != null && !activityId.trim().isEmpty();
    }
}
