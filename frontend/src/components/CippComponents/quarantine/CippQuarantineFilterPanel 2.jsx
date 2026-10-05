import { useState } from "react";
import { Button, Collapse, Grid, Stack, Typography } from "@mui/material";
import { ClearAll, ExpandLess, ExpandMore, Search } from "@mui/icons-material";
import CippFormComponent from "../CippFormComponent";
import CippButtonCard from "../../CippCards/CippButtonCard";
import {
  POLICY_TYPE_OPTIONS,
  QUARANTINE_DAYS_OPTIONS,
  QUARANTINE_TIME_PRESETS,
  QUARANTINE_TYPE_OPTIONS,
  RELEASE_STATUS_OPTIONS,
} from "./quarantineConstants";

const isIPAddress = {
  validate: (value) =>
    !value ||
    /^(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)\.(25[0-5]|2[0-4]\d|[01]?\d\d?)$/.test(
      value
    ) ||
    /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/.test(value) ||
    "Invalid IP address",
};

const CippQuarantineFilterPanel = ({
  formControl,
  onSearch,
  onClear,
  onPreset,
  activePreset,
  showTraceFilters = false,
  disabled = false,
  title = "Search Quarantine",
}) => {
  const [showAdvanced, setShowAdvanced] = useState(false);
  const isMessageIdSet = !!formControl.watch("messageId");

  return (
    <Stack spacing={1}>
      <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
        <Typography variant="body2" color="text.secondary" sx={{ mr: 1 }}>
          Quick ranges:
        </Typography>
        {QUARANTINE_TIME_PRESETS.map((preset) => (
          <Button
            key={preset.key}
            size="small"
            variant={activePreset === preset.key ? "contained" : "outlined"}
            onClick={() => onPreset?.(preset)}
            disabled={disabled}
          >
            {preset.label}
          </Button>
        ))}
      </Stack>

      <CippButtonCard component="accordion" title={title} accordionExpanded>
        <Grid container spacing={2}>
          <Grid size={12}>
            <CippFormComponent
              type="radio"
              row
              name="dateFilter"
              label="Date Range"
              options={[
                { label: "Relative", value: "relative" },
                { label: "Custom", value: "startEnd" },
              ]}
              formControl={formControl}
              disabled={isMessageIdSet || disabled}
            />
          </Grid>
          {formControl.watch("dateFilter") === "relative" && (
            <Grid size={{ xs: 12, md: 4 }}>
              <CippFormComponent
                type="autoComplete"
                name="days"
                label="Time Range"
                multiple={false}
                creatable={false}
                options={QUARANTINE_DAYS_OPTIONS}
                formControl={formControl}
                disabled={isMessageIdSet || disabled}
              />
            </Grid>
          )}
          {formControl.watch("dateFilter") === "startEnd" && (
            <>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="datePicker"
                  name="startDate"
                  label="Start Date"
                  dateTimeType="datetime"
                  formControl={formControl}
                  disabled={isMessageIdSet || disabled}
                />
              </Grid>
              <Grid size={{ xs: 12, md: 6 }}>
                <CippFormComponent
                  type="datePicker"
                  name="endDate"
                  label="End Date"
                  dateTimeType="datetime"
                  formControl={formControl}
                  disabled={isMessageIdSet || disabled}
                />
              </Grid>
            </>
          )}
          <Grid size={{ xs: 12, md: 6 }}>
            <CippFormComponent
              type="autoComplete"
              freeSolo
              multiple
              creatable
              name="sender"
              label="Sender Email"
              formControl={formControl}
              disabled={isMessageIdSet || disabled}
            />
          </Grid>
          <Grid size={{ xs: 12, md: 6 }}>
            <CippFormComponent
              type="autoComplete"
              freeSolo
              multiple
              creatable
              name="recipient"
              label="Recipient Email"
              formControl={formControl}
              disabled={isMessageIdSet || disabled}
            />
          </Grid>
          <Grid size={{ xs: 12, md: 6 }}>
            <CippFormComponent
              type="textField"
              name="subject"
              label="Subject Contains"
              formControl={formControl}
              disabled={isMessageIdSet || disabled}
            />
          </Grid>
          <Grid size={{ xs: 12, md: 6 }}>
            <CippFormComponent
              type="textField"
              name="messageId"
              label="Message / Internet Message ID"
              formControl={formControl}
              disabled={disabled}
            />
          </Grid>

          <Grid size={12}>
            <Button
              size="small"
              onClick={() => setShowAdvanced(!showAdvanced)}
              endIcon={showAdvanced ? <ExpandLess /> : <ExpandMore />}
            >
              Advanced Filters
            </Button>
          </Grid>
          <Grid size={12}>
            <Collapse in={showAdvanced}>
              <Grid container spacing={2}>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="textField"
                    name="subjectExact"
                    label="Exact Subject (server filter)"
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="textField"
                    name="senderDomain"
                    label="Sender Domain"
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="textField"
                    name="recipientDomain"
                    label="Recipient Domain"
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="textField"
                    name="policyName"
                    label="Policy Name"
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="autoComplete"
                    name="quarantineType"
                    label="Quarantine Reason"
                    options={QUARANTINE_TYPE_OPTIONS}
                    multiple
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="autoComplete"
                    name="releaseStatus"
                    label="Release Status"
                    options={RELEASE_STATUS_OPTIONS}
                    multiple
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 6 }}>
                  <CippFormComponent
                    type="autoComplete"
                    name="policyTypes"
                    label="Policy Type"
                    options={POLICY_TYPE_OPTIONS}
                    multiple
                    formControl={formControl}
                    disabled={isMessageIdSet || disabled}
                  />
                </Grid>
                {showTraceFilters && (
                  <>
                    <Grid size={{ xs: 12, md: 6 }}>
                      <CippFormComponent
                        type="textField"
                        name="fromIP"
                        label="Sending IP (message trace only)"
                        formControl={formControl}
                        validators={isIPAddress}
                        disabled={isMessageIdSet || disabled}
                      />
                    </Grid>
                    <Grid size={{ xs: 12, md: 6 }}>
                      <CippFormComponent
                        type="textField"
                        name="toIP"
                        label="Destination IP (message trace only)"
                        formControl={formControl}
                        validators={isIPAddress}
                        disabled={isMessageIdSet || disabled}
                      />
                    </Grid>
                    <Grid size={{ xs: 12, md: 6 }}>
                      <CippFormComponent
                        type="autoComplete"
                        name="status"
                        label="Delivery Status (message trace only)"
                        options={[
                          { label: "Delivered", value: "Delivered" },
                          { label: "Failed", value: "Failed" },
                          { label: "Quarantined", value: "Quarantined" },
                          { label: "Filtered As Spam", value: "FilteredAsSpam" },
                        ]}
                        multiple
                        formControl={formControl}
                        disabled={isMessageIdSet || disabled}
                      />
                    </Grid>
                  </>
                )}
              </Grid>
            </Collapse>
          </Grid>

          <Grid size={12} sx={{ display: "flex", gap: 1 }}>
            <Button
              onClick={onSearch}
              variant="contained"
              color="primary"
              startIcon={<Search />}
              disabled={disabled}
            >
              Search
            </Button>
            <Button onClick={onClear} variant="outlined" startIcon={<ClearAll />} disabled={disabled}>
              Clear
            </Button>
          </Grid>
        </Grid>
      </CippButtonCard>
    </Stack>
  );
};

export default CippQuarantineFilterPanel;
